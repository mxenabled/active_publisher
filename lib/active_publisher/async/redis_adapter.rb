require "concurrent"
require "active_publisher/message"

module ActivePublisher
  module Async
    module RedisAdapter
      REDIS_SET_KEY = "ACTIVE_PUBLISHER_SET".freeze

      def self.waiting_message_count
        @waiting_message_count ||= ::Concurrent::AtomicFixnum.new
      end
      waiting_message_count

      def self.new(*args)
        ::ActivePublisher::Async::RedisAdapter::Adapter.new(*args)
      end

      class Adapter
        REDIS_ASYNC_WRITER = ::ActivePublisher::Async::RedisAdapter::Adapter::RedisAsyncWriter.new

        include ::ActivePublisher::Logging

        attr_reader :async_queue, :redis_pool

        def initialize(new_redis_pool)
          logger.info "Starting redis publisher adapter"
          # do something with supervision ?
          @redis_pool = new_redis_pool
          @async_queue = ::ActivePublisher::Async::RedisAdapter::Consumer.new(redis_pool)
        end

        def publish(route, payload, exchange_name, options = {})
          ::ActivePublisher::Async::RedisAdapter.waiting_message_count.increment
          message = ::ActivePublisher::Message.new(route, payload, exchange_name, options)
          REDIS_ASYNC_WRITER.push(redis_pool, message)

          nil
        end

        def shutdown!
          max_wait_time = ::ActivePublisher.configuration.seconds_to_wait_for_graceful_shutdown
          started_shutting_down_at = ::Time.now
          waiting_message_size = self.class.waiting_message_count.value

          logger.info "Draining async publisher redis adapter before shutdown. current size: #{waiting_message_size}"
          while waiting_message_size > 0
            if (::Time.now - started_shutting_down_at) > max_wait_time
              logger.info "Forcing redis publisher adapter shutdown because graceful shutdown period of #{max_wait_time} seconds was exceeded. Current size: #{waiting_message_size}."
              break
            end

            sleep 0.1
          end
        end

      end
    end
  end
end
