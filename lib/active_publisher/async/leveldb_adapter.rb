require "leveldb"
require "time"

require "active_publisher/async/leveldb_adapter/async_queue"
require "active_publisher/async/leveldb_adapter/consumer_thread"

module ActivePublisher
  module Async
    module LeveldbAdapter
      def self.new(*args)
        ::ActivePublisher::Async::LeveldbAdapter::Adapter.new(*args)
      end

      class UnableToPersistMessageError < ::StandardError; end

      class Message < Struct.new(:route, :payload, :exchange_name, :options, :retries)
        def self.from_json(json)
          hash = JSON.parse(json)
          new(hash["route"], hash["payload"], hash["exchange_name"], hash["options"], hash["retries"])
        end

        def to_json
          {:route => route, :payload => payload, :exchange_name => exchange_name, :options => options, :retries => retries}.to_json
        end
      end

      class Adapter
        include ::ActivePublisher::Logging

        attr_reader :async_queue

        def initialize(back_pressure_strategy = :raise, max_queue_size = 10_000_000, supervisor_interval = 0.2)
          logger.info "Starting leveldb publisher adapter"

          @async_queue = ::ActivePublisher::Async::LeveldbAdapter::AsyncQueue.new(
            back_pressure_strategy,
            max_queue_size,
            supervisor_interval
          )
        end

        def publish(route, payload, exchange_name, options = {})
          message = Message.new(route, payload, exchange_name, options, 0)
          async_queue.push(message)
          nil
        end

        def shutdown!
          # No-op since all messages will be retried on restart.
        end

      end
    end
  end
end
