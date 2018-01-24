module ActivePublisher
  module Async
    module RedisAdapter
      class RedisMultiPopQueue
        attr_reader :list_key, :redis_pool

        def initialize(redis_connection_pool, new_list_key)
          @redis_pool = redis_connection_pool
          @list_key = new_list_key
        end

        def <<(message)
          encoded_message = ::Marshal.dump(message)

          redis_pool.with do |redis|
            redis.rpush(list_key, encoded_message)
          end
        end

        def concat(*messages)
          messages = messages.flatten
          messages.compact!
          return if messages.empty?

          encoded_messages = []
          messages.each do |message|
            encoded_messages << ::Marshal.dump(message)
          end

          redis_pool.with do |redis|
            redis.rpush(list_key, encoded_messages)
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

          queue_size = size
          if queue_size <= 0
            if non_block
              raise ThreadError, "queue empty"
            else
              total_waited_time = 0

              loop do
                total_waited_time += 0.1
                sleep 0.1
                queue_size = size

                if queue_size > 0
                  num_to_pop = [num_to_pop, queue_size].min # make sure we don't pop more than size
                  return shift(num_to_pop)
                end

                return if timeout && total_waited_time > timeout
              end
            end
          else
            shift(num_to_pop)
          end
        end

        def shift(number)
          number = [number, size].min
          return [] if number <= 0

          messages = []
          multi_response = []
          redis_pool.with do |redis|
            multi_response = redis.multi do
              redis.lrange(list_key, 0, number - 1)
              redis.ltrim(list_key, number, -1)
            end
          end

          messages = multi_response.first
          messages = [] if messages.nil?
          messages = [messages] unless messages.respond_to?(:each)

          shifted_messages = []
          messages.each do |message|
            next if message.nil?

            shifted_messages << ::Marshal.load(message)
          end

          shifted_messages
        end

        def size
          redis_pool.with do |redis|
            redis.llen(list_key) || 0
          end
        end
      end

    end
  end
end
