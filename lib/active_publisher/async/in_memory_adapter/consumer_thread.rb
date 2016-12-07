module ActivePublisher
  module Async
    module InMemoryAdapter
      class ConsumerThread
        attr_reader :thread, :queue, :sampled_queue_size

        if ::RUBY_PLATFORM == "java"
          NETWORK_ERRORS = [::MarchHare::Exception, ::Java::ComRabbitmqClient::AlreadyClosedException, ::Java::JavaIo::IOException].freeze
        else
          NETWORK_ERRORS = [::Bunny::Exception, ::Timeout::Error, ::IOError].freeze
        end

        def initialize(listen_queue)
          @queue = listen_queue
          @sampled_queue_size = queue.size
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
          if defined?(ActivePublisher::RabbitConnection)
            sleep ::ActivePublisher::RabbitConnection::NETWORK_RECOVERY_INTERVAL
          else
            sleep 0.1
          end
        end

        def start_thread
          return if alive?
          @thread = ::Thread.new do
            loop do
              # Sample the queue size so we don't shutdown when messages are in flight.
              @sampled_queue_size = queue.size
              current_messages = queue.pop_up_to(20)

              begin
                # Only open a single connection for each group of messages to an exchange
                current_messages.group_by(&:exchange_name).each do |exchange_name, messages|
                  begin
                    current_messages -= messages
                    ::ActivePublisher.publish_all(exchange_name, messages)
                  ensure
                    current_messages.concat(messages)
                  end
                end
              rescue *NETWORK_ERRORS
                # Sleep because connection is down
                await_network_reconnect

                # Requeue and try again.
                queue.concat(current_messages)
              rescue => unknown_error
                current_messages.each do |message|
                  # Degrade to single message publish ... or at least attempt to
                  begin
                    ::ActivePublisher.publish(message.route, message.payload, message.exchange_name, message.options)
                  rescue
                    ::ActivePublisher.configuration.error_handler.call(unknown_error, {:route => message.route, :payload => message.payload, :exchange_name => message.exchange_name, :options => message.options})
                  end
                end

                # TODO: Find a way to bubble this out of the thread for logging purposes.
                # Reraise the error out of the publisher loop. The Supervisor will restart the consumer.
                raise unknown_error
              end
            end
          end
        end
      end
    end
  end
end
