module ActivePublisher
  module Async
    module RedisAdapter
      class RedisAsyncWriter
        include ::Concurrent::Async

        def push(redis_connection_pool, message)
          encoded_message = ::Marshal.dump(message)
          redis_connection_pool.with do |redis|
            redis.sadd(::ActivePublisher::Async::RedisAdapter::REDIS_SET_KEY, message)
          end
        ensure
          ::ActivePublisher::Async::RedisAdapter.waiting_message_count.decrement
        end
      end
    end
  end
end
