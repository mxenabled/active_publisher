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

        attr_reader :consumer, :queue, :supervisor

        def initialize(back_pressure_strategy, max_queue_size, supervisor_interval)
          self.back_pressure_strategy = back_pressure_strategy
          @max_queue_size = max_queue_size
          @supervisor_interval = supervisor_interval
          @queue = ::MultiOpQueue::Queue.new
          create_and_supervise_consumer!
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

          @last_pushed_at = ::Time.now
          queue.push(message)
        end

        def size
          # Requests might be in flight (out of the queue, but not yet published), so taking the max should be
          # good enough to make sure we're honest about the actual queue size.
          return queue.size if consumer.nil?
          [queue.size, consumer.sampled_queue_size].max
        end

        private

        def create_and_supervise_consumer!
          @consumer = ::ActivePublisher::Async::InMemoryAdapter::ConsumerThread.new(queue)
          @last_pushed_at = ::Time.now
          @last_heartbeat_at = ::Time.now
          @ticks_before_restart = 5

          supervisor_task = ::Concurrent::TimerTask.new(:execution_interval => supervisor_interval) do
            current_time = ::Time.now

            # Process heartbeats from the consumer.
            if !consumer.heartbeats.empty?
              @last_heartbeat_at = current_time
              consumer.heartbeats.clear
            end

            # Consumer is lagging if all of the following are true:
            # 1. We have not received a heartbeat from the consumer thread in more than 10 seconds.
            # 2. A message has been pushed onto the queue since the last heartbeat message.
            # 3. The supervisor has waited 5 "ticks" since (1) and (2) became true.
            consumer_is_lagging = (current_time - @last_heartbeat_at) > 10 &&
                                  (@last_heartbeat_at < @last_pushed_at) &&
                                  (@ticks_before_restart -=1) <= 0

            # Check to see if we should restart the consumer.
            if !consumer.alive? || consumer_is_lagging
              consumer.kill
              @consumer = ::ActivePublisher::Async::InMemoryAdapter::ConsumerThread.new(queue)
              @last_pushed_at = ::Time.now
              @last_heartbeat_at = ::Time.now
              @ticks_before_restart = 5
            end

            # Notify the current queue size.
            ::ActiveSupport::Notifications.instrument "async_queue_size.active_publisher", queue.size
          end
          supervisor_task.execute
        end
      end

    end
  end
end
