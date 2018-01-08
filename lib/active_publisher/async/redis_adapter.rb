require "active_publisher/message"
require "active_publisher/async/redis_adapter/consumer"
require "multi_op_queue"

module ActivePublisher
  module Async
    module RedisAdapter
      REDIS_SET_KEY = "ACTIVE_PUBLISHER_SET".freeze

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
            flush_queue!
          end

          supervisor_task.execute
        end

        def publish(route, payload, exchange_name, options = {})
          message = ::ActivePublisher::Message.new(route, payload, exchange_name, options)
          queue << ::Marshal.dump(message)
          flush_queue! if queue.size >= 20

          nil
        end

        def shutdown!
          logger.info "Draining async publisher redis adapter before shutdown."
          flush_queue! until queue.empty?
          sleep 0.5
        end

      private

        def flush_queue!
          return if queue.empty?
          encoded_messages = queue.pop_up_to(25, :timeout => 0.1)

          return if encoded_messages.nil?
          return unless encoded_messages.respond_to?(:each)
          return unless encoded_messages.size > 0

          redis_pool.with do |redis|
            redis.pipelined do
              encoded_messages.each do |encoded_message|
                redis.sadd(::ActivePublisher::Async::RedisAdapter::REDIS_SET_KEY, encoded_message)
              end
            end
          end
        end
      end
    end
  end
end
