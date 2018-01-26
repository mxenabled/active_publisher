require "active_publisher"
require "active_publisher/message"
require "active_publisher/async/redis_adapter/consumer"
require "multi_op_queue"

module ActivePublisher
  module Async
    module RedisAdapter
      REDIS_LIST_KEY = "ACTIVE_PUBLISHER_LIST".freeze

      def self.new(*args)
        ::ActivePublisher::Async::RedisAdapter::Adapter.new(*args)
      end

      class Adapter
        SUPERVISOR_INTERVAL = {
          :execution_interval => 1.5, # seconds
          :timeout_interval => 1, # seconds
        }
        include ::ActivePublisher::Logging

        attr_reader :async_queue, :redis_pool, :queue

        def initialize(new_redis_pool)
          logger.info "Starting redis publisher adapter"
          # do something with supervision ?
          @redis_pool = new_redis_pool
          @async_queue = ::ActivePublisher::Async::RedisAdapter::Consumer.new(redis_pool)
          @queue = ::MultiOpQueue::Queue.new

          supervisor_task = ::Concurrent::TimerTask.new(SUPERVISOR_INTERVAL) do
            queue_size = queue.size
            number_of_times = [queue_size / 50, 1].max # get the max number of times to flush
            number_of_times = [number_of_times, 5].min # don't allow it to be more than 5 per run
            number_of_times.times { flush_queue! }
          end

          supervisor_task.execute
        end

        def publish(route, payload, exchange_name, options = {})
          message = ::ActivePublisher::Message.new(route, payload, exchange_name, options)
          queue << ::Marshal.dump(message)
          flush_queue! if queue.size >= 20 || options[:flush_queue]

          nil
        end

        def shutdown!
          logger.info "Draining async publisher redis adapter before shutdown."
          flush_queue! until queue.empty?
          # Sleeping 2.1 seconds because the most common redis `fsync` command in AOF mode is run every 1 second
          # this will give at least 1 full `fsync` to run before the process dies
          sleep 2.1
        end

      private

        def flush_queue!
          return if queue.empty?
          encoded_messages = queue.pop_up_to(25, :timeout => 0.001)

          return if encoded_messages.nil?
          return unless encoded_messages.respond_to?(:each)
          return unless encoded_messages.size > 0

          redis_pool.with do |redis|
            redis.rpush(::ActivePublisher::Async::RedisAdapter::REDIS_LIST_KEY, encoded_messages)
          end
        end
      end
    end
  end
end
