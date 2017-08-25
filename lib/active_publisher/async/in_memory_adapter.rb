require "active_publisher/message"
require "active_publisher/async/in_memory_adapter/async_queue"
require "active_publisher/async/in_memory_adapter/consumer_thread"
require "multi_op_queue"

module ActivePublisher
  module Async
    module InMemoryAdapter

      def self.new(*args)
        ::ActivePublisher::Async::InMemoryAdapter::Adapter.new(*args)
      end

      class UnableToPersistMessageError < ::StandardError; end

      class Adapter
        include ::ActivePublisher::Logging

        attr_reader :async_queue

        def initialize(back_pressure_strategy = :raise, max_queue_size = 1_000_000, supervisor_interval = 0.2)
          logger.info "Starting in-memory publisher adapter"

          @async_queue = ::ActivePublisher::Async::InMemoryAdapter::AsyncQueue.new(
            back_pressure_strategy,
            max_queue_size,
            supervisor_interval
          )
        end

        def publish(route, payload, exchange_name, options = {})
          message = ::ActivePublisher::Message.new(route, payload, exchange_name, options)
          async_queue.push(message)
          nil
        end

        def shutdown!
          max_wait_time = ::ActivePublisher.configuration.seconds_to_wait_for_graceful_shutdown
          started_shutting_down_at = ::Time.now

          logger.info "Draining async publisher in-memory adapter queue before shutdown. current queue size: #{async_queue.size}."
          while async_queue.size > 0
            if (::Time.now - started_shutting_down_at) > max_wait_time
              logger.info "Forcing async publisher adapter shutdown because graceful shutdown period of #{max_wait_time} seconds was exceeded. Current queue size: #{async_queue.size}."
              break
            end

            sleep 0.1
          end
        end

      end
    end
  end
end
