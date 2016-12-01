module ActivePublisher
  module Async
    module InMemoryAdapter
      class ConsumerThread
        attr_reader :current_messages, :thread, :queue

        if ::RUBY_PLATFORM == "java"
          NETWORK_ERRORS = [::MarchHare::Exception, ::Java::ComRabbitmqClient::AlreadyClosedException, ::Java::JavaIo::IOException].freeze
        else
          NETWORK_ERRORS = [::Bunny::Exception, ::Timeout::Error, ::IOError].freeze
        end

        def initialize(listen_queue)
          @current_messages = []
          @queue = listen_queue
          start_thread
        end

        def alive?
          @thread && @thread.alive?
        end

        def kill
          @thread.kill if @thread
          @thread = nil
        end

        private

        def await_network_reconnect
          if defined?(ActivePublisher::Connection::NETWORK_RECOVERY_INTERVAL)
            sleep ::ActivePublisher::Connection::NETWORK_RECOVERY_INTERVAL
          else
            sleep 0.1
          end
        end

        def start_thread
          return if alive?
          @thread = ::Thread.new do
            loop do
              # Write "current_messages" so we can requeue should something happen to the consumer.
              @current_messages = queue.pop_up_to(20)
              messages_by_exchange = @current_messages.group_by(&:exchange_name)
              messages_by_exchange.each do |exchange_name, messages|
                messages_to_retry = []
                begin
                  begin
                    ::ActivePublisher.publish_all(exchange_name, messages)
                  ensure
                    messages_to_retry.concat(messages)
                  end
                rescue *NETWORK_ERRORS
                  # Sleep because connection is down
                  await_network_reconnect
                  queue.concat(messages_to_retry) unless messages_to_retry.empty?
                rescue => unknown_error
                  messages_to_retry.each do |message|
                    # Degrade to single message publish ... or at least attempt to
                    begin
                      ::ActivePublisher.publish(message.route, message.payload, message.exchange_name, message.options)
                    rescue => error
                      ::ActivePublisher.configuration.error_handler.call(unknown_error, {:route => message.route, :payload => message.payload, :exchange_name => message.exchange_name, :options => message.options})
                    end
                  end
                end
                @current_messages -= messages
              end
            end
          end
        end
      end
    end
  end
end
