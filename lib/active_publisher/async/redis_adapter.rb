require "active_publisher/message"
require "active_publisher/async/redis_adapter/consumer"

module ActivePublisher
  module Async
    module RedisAdapter
      REDIS_SET_KEY = "ACTIVE_PUBLISHER_SET".freeze

      def self.new(*args)
        ::ActivePublisher::Async::RedisAdapter::Adapter.new(*args)
      end

      class Adapter
        include ::ActivePublisher::Logging

        attr_reader :async_queue, :redis_pool

        def initialize(new_redis_pool)
          logger.info "Starting redis publisher adapter"
          # do something with supervision ?
          @redis_pool = new_redis_pool
          @async_queue = ::ActivePublisher::Async::RedisAdapter::Consumer.new(redis_pool)
        end

        def publish(route, payload, exchange_name, options = {})
          message = ::ActivePublisher::Message.new(route, payload, exchange_name, options)

          encoded_message = ::Marshal.dump(message)
          redis_pool.with do |redis|
            redis.sadd(::ActivePublisher::Async::RedisAdapter::REDIS_SET_KEY, encoded_message)
          end

          nil
        end

        def shutdown!
          max_wait_time = ::ActivePublisher.configuration.seconds_to_wait_for_graceful_shutdown
          started_shutting_down_at = ::Time.now

          logger.info "Draining async publisher redis adapter before shutdown."
          sleep 0.5
        end
      end
    end
  end
end
