module ActivePublisher
  module Async
    module InMemoryAdapter
      ##
      # This class is a wrapper around bunny and march hare channels to cache exchanges.
      # Bunny does this by default, but march hare will perform a blocking wait for each
      # exchange declaration.
      #
      class Channel
        attr_reader :rabbit_channel, :topic_exchange_cache

        def initialize
          @topic_exchange_cache = {}
          @rabbit_channel = ::ActivePublisher::Connection.connection.create_channel
        end

        def close
          rabbit_channel.close
        end

        def confirm_select
          rabbit_channel.confirm_select
        end

        def topic(exchange)
          topic_exchange_cache[exchange] ||= rabbit_channel.topic(exchange)
        end

        def using_publisher_confirms?
          rabbit_channel.using_publisher_confirms?
        end

        def wait_for_confirms(timeout)
          if rabbit_channel.method(:wait_for_confirms).arity > 0
            rabbit_channel.wait_for_confirms(timeout)
          else
            rabbit_channel.wait_for_confirms
          end
        end
      end
    end
  end
end
