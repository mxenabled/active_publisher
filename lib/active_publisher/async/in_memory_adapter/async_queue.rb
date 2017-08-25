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
              return
            when :raise
              fail ::ActivePublisher::Async::InMemoryAdapter::UnableToPersistMessageError, "Queue is full, messages will be dropped."
            when :wait
              # This is a really crappy way to wait
              sleep 0.01 until queue.size < max_queue_size
            end
          end

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
          @supervisor = ::Thread.new do
            loop do
              unless consumer.alive?
                consumer.kill
                @consumer = ::ActivePublisher::Async::InMemoryAdapter::ConsumerThread.new(queue)
              end

              # Pause before checking the consumer again.
              sleep supervisor_interval
            end
          end
        end
      end

    end
  end
end
