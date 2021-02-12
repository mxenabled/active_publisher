module ActivePublisher
  module Async
    module InMemoryAdapter
      class AsyncQueue
        # These strategies are used to determine what to do with messages when the queue is full.
        # :raise - Raise an error and drop the message.
        # :drop - Silently drop the message.
        # :wait - Wait for space in the queue to become available.
        BACK_PRESSURE_STRATEGIES = [:raise, :drop, :wait].freeze

        include ::ActivePublisher::Logging

        attr_accessor :back_pressure_strategy,
          :max_queue_size,
          :supervisor_interval

        attr_reader :consumers, :queue, :supervisor

        def initialize(back_pressure_strategy, max_queue_size, supervisor_interval)
          self.back_pressure_strategy = back_pressure_strategy
          @max_queue_size = max_queue_size
          @supervisor_interval = supervisor_interval
          @queue = ::MultiOpQueue::Queue.new
          @consumers = {}
          create_and_supervise_consumers!
        end

        def back_pressure_strategy=(strategy)
          fail ::ArgumentError, "Invalid back pressure strategy: #{strategy}" unless BACK_PRESSURE_STRATEGIES.include?(strategy)
          @back_pressure_strategy = strategy
        end

        def push(message)
          if queue.size >= max_queue_size
            case back_pressure_strategy
            when :drop
              ::ActiveSupport::Notifications.instrument "message_dropped.active_publisher"
              return
            when :raise
              ::ActiveSupport::Notifications.instrument "message_dropped.active_publisher"
              fail ::ActivePublisher::Async::InMemoryAdapter::UnableToPersistMessageError, "Queue is full, messages will be dropped."
            when :wait
              ::ActiveSupport::Notifications.instrument "wait_for_async_queue.active_publisher" do
                # This is a really crappy way to wait
                sleep 0.01 until queue.size < max_queue_size
              end
            end
          end

          queue.push(message)
        end

        def size
          # Requests might be in flight (out of the queue, but not yet published), so taking the max should be
          # good enough to make sure we're honest about the actual queue size.
          return queue.size if consumers.empty?
          [queue.size, consumer_sampled_queue_size].max
        end

        private

        def create_and_supervise_consumers!
          ::ActivePublisher.configuration.publisher_threads.times do
            consumer_id = ::SecureRandom.uuid
            consumers[consumer_id] = ::ActivePublisher::Async::InMemoryAdapter::ConsumerThread.new(queue)
            supervisor_task = ::Concurrent::TimerTask.new(:execution_interval => supervisor_interval) do
              current_time = ::Time.now
              consumer = consumers[consumer_id]

              # Consumer is lagging if it does not "tick" at least once every 10 seconds.
              seconds_since_last_tick = current_time - consumer.last_tick_at
              consumer_is_lagging = seconds_since_last_tick > ::ActivePublisher.configuration.max_async_publisher_lag_time
              logger.error "ActivePublisher consumer is lagging. Last consumer tick was #{seconds_since_last_tick} seconds ago." if consumer_is_lagging

              # Check to see if we should restart the consumer.
              if !consumer.alive? || consumer_is_lagging
                consumer.kill rescue nil
                consumers[consumer_id] = ::ActivePublisher::Async::InMemoryAdapter::ConsumerThread.new(queue)
              end

              # Notify the current queue size.
              ::ActiveSupport::Notifications.instrument "async_queue_size.active_publisher", queue.size
            end
            supervisor_task.execute
          end
        end

        def consumer_sampled_queue_size
          consumers.values.map(&:sampled_queue_size).max
        end

      end
    end
  end
end
