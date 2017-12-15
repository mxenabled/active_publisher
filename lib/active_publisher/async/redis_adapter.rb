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
        include ::ActivePublisher::Logging

        attr_reader :async_queue, :redis_pool

        ##
        # Use a "pool" of 5 async publisher objects that get fairly balanced with `with` method
        #
        POOL = ::Queue.new
        POOL_SIZE = 5
        POOL_SIZE.times { POOL << ::ActivePublisher::Async::RedisAdapter::Adapter::RedisAsyncWriter.new }

        def self.with
          writer = nil
          yield writer = POOL.pop
        ensure
          POOL.push(writer) if writer
        end

        def initialize(new_redis_pool, supervisor_interval = 0.2)
          logger.info "Starting redis publisher adapter"
          # do something with supervision ?
          @redis_pool = new_redis_pool
        end

        def publish(route, payload, exchange_name, options = {})
          ::ActivePublisher::Async::RedisAdapter.waiting_message_count.increment
          message = ::ActivePublisher::Message.new(route, payload, exchange_name, options)
          self.with do |writer|
            writer.push(redis_pool, message)
          end

          nil
        end

        def shutdown!
          max_wait_time = ::ActivePublisher.configuration.seconds_to_wait_for_graceful_shutdown
          started_shutting_down_at = ::Time.now
          waiting_message_size = self.class.waiting_message_count

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
