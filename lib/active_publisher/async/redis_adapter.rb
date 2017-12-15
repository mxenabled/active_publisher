require "concurrent"
require "msgpack"
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
        ::ActivePublisher::Async::InMemoryAdapter::Adapter.new(*args)
      end

      class UnableToPersistMessageError < ::StandardError; end

      class Adapter
        include ::ActivePublisher::Logging

        attr_reader :async_queue, :redis_pool

        class RedisQueue
          attr_reader :redis_pool

          def initialize(redis_connection_pool)
            @redis_pool = redis_connection_pool
          end

          def concat(messages)
            encoded_messages = []
            messages.each do |message|
              encoded_messages << ::MessagePack.pack(message) 
            end

            redis_pool.with do |redis|
              redis.sadd(::ActivePublisher::Async::RedisAdapter::REDIS_SET_KEY, *encoded_messages)
            end
          end

          def empty?
            size <= 0
          end

          def pop_up_to(num_to_pop, opts = {})
            case opts
            when TrueClass, FalseClass
              non_bock = opts
            when Hash
              timeout = opts.fetch(:timeout, nil)
              non_block = opts.fetch(:non_block, false)
            end

            if empty?
              if non_block
                raise ThreadError, "queue empty"
              else
                loop do
                  total_waited_time += 0.2
                  sleep 0.2
                  return shift(num_to_pop) if !empty? 
                  return if timeout && total_waited_time > timeout
                end
              end
            else
              shift(num_to_pop)
            end
          end

          def shift(number)
            messages = []
            redis_pool.with do |redis|
              messages = redis.spop(::ActivePublisher::Async::RedisAdapter::REDIS_SET_KEY, number)
            end

            messages.map { |message| ::MessagePack.unpack(messsage) }
          end

          def size
            redis_pool.with do |redis|
              redis.scard || 0
            end
          end
        end

        class RedisWriter
          include ::Concurrent::Async

          def push(redis_connection_pool, message)
            encoded_message = ::MessagePack.pack(message) 
            redis_connection_pool.with do |redis|
              redis.sadd(::ActivePublisher::Async::RedisAdapter::REDIS_SET_KEY, message)
            end
          ensure
            ::ActivePublisher::Async::RedisAdapter.waiting_message_count.decrement
          end
        end
        
        ##
        # Use a "pool" of 2 async publisher objects that get fairly balanced with `with` method
        #
        POOL = ::Queue.new
        POOL_SIZE = 10
        POOL_SIZE.times { POOL << ::ActivePublisher::Async::RedisAdapter::Adapter::RedisWriter.new }

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
