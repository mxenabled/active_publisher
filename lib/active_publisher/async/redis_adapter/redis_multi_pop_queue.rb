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
            redis.lpush(::ActivePublisher::Async::RedisAdapter::REDIS_LIST_KEY, encoded_messages)
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
            redis.pipelined do
              number.times do
                messages << redis.rpop(::ActivePublisher::Async::RedisAdapter::REDIS_LIST_KEY)
              end
            end
          end

          messages = [] if messages.nil?
          messages = [messages] unless messages.respond_to?(:each)
          messages.compact!
          messages.map { |message| ::Marshal.load(messsage) }
        end

        def size
          redis_pool.with do |redis|
            redis.llen(::ActivePublisher::Async::RedisAdapter::REDIS_LIST_KEY) || 0
          end
        end
      end

    end
  end
end
