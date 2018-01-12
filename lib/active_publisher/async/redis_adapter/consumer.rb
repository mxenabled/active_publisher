require "active_publisher/async/redis_adapter/redis_multi_pop_queue"

module ActivePublisher
  module Async
    module RedisAdapter
      class Consumer
        SUPERVISOR_INTERVAL = {
          :execution_interval => 10, # seconds
          :timeout_interval => 5, # seconds
        }

        attr_reader :consumer, :queue, :supervisor

        def initialize(redis_pool)
          @queue = ::ActivePublisher::Async::RedisAdapter::RedisMultiPopQueue.new(redis_pool, ::ActivePublisher::Async::RedisAdapter::REDIS_LIST_KEY)
          create_and_supervise_consumer!
        end

        def create_and_supervise_consumer!
          @consumer = ::ActivePublisher::Async::InMemoryAdapter::ConsumerThread.new(queue)

          supervisor_task = ::Concurrent::TimerTask.new(SUPERVISOR_INTERVAL) do
            # This may also be the place to start additional publishers when we are getting backed up ... ?
            unless consumer.alive?
              consumer.kill rescue nil
              @consumer = ::ActivePublisher::Async::InMemoryAdapter::ConsumerThread.new(queue)
            end

            # Notify the current queue size.
            ::ActiveSupport::Notifications.instrument "redis_async_queue_size.active_publisher", queue.size
          end

          supervisor_task.execute
        end
      end

    end
  end
end
