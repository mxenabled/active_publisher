module ActivePublisher
  module Async
    module RedisAdapter
      class RedisMultiPopQueue
        attr_reader :redis_pool

        def initialize(redis_connection_pool)
          @redis_pool = redis_connection_pool
        end

        def concat(messages)
          encoded_messages = []
          messages.each do |message|
            encoded_messages << ::Marshal.dump(message)
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
              total_waited_time = 0

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

          messages.map { |message| ::Marshal.load(messsage) }
        end

        def size
          redis_pool.with do |redis|
            redis.scard(::ActivePublisher::Async::RedisAdapter::REDIS_SET_KEY) || 0
          end
        end
      end

    end
  end
end
