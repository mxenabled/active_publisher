module ActivePublisher
  module Async
    module LeveldbAdapter
      class ConsumerThread
        attr_reader :thread, :queue

        if ::RUBY_PLATFORM == "java"
          NETWORK_ERRORS = [::MarchHare::Exception, ::Java::ComRabbitmqClient::AlreadyClosedException, ::Java::JavaIo::IOException].freeze
        else
          NETWORK_ERRORS = [::Bunny::Exception, ::Timeout::Error, ::IOError].freeze
        end

        def initialize(queue)
          @queue = queue
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

        def make_channel
          channel = ::ActivePublisher::Connection.connection.create_channel
          channel.confirm_select if ::ActivePublisher.configuration.publisher_confirms
          channel
        end

        def process_batch_of_messages(channel, exchange_name, key_message_pairs)
          messages = key_message_pairs.map(&:last)
          publish_all(channel, exchange_name, messages)
        rescue
          # One or more messages failed. Schedule to retry in the future.
          key_message_pairs.each { |key, message| queue.retry(key, message) }
          raise
        else
          # Messages have been published.
          key_message_pairs.each { |key, _message| queue.delete(key) }
        end

        def publish_all(channel, exchange_name, messages)
          ::ActiveSupport::Notifications.instrument "message_published.active_publisher", :message_count => messages.size do
            exchange = channel.topic(exchange_name)
            messages.each do |message|
              fail ActivePublisher::ExchangeMismatchError, "bulk publish messages must match publish_all exchange_name" if message.exchange_name != exchange_name

              options = ::ActivePublisher.publishing_options(message.route, message.options || {})
              exchange.publish(message.payload, options)
            end
            wait_for_confirms(channel, messages)
          end
        end

        def start_thread
          return if alive?
          @thread = ::Thread.new do
            begin
              loop do
                # TODO: Switch this for a cond variable.
                sleep 0.1 if queue.empty?

                # Get up to 50 messages
                current_messages = queue.next_batch_of_messages(50)
                next if current_messages.empty?

                begin
                  @channel ||= make_channel

                  current_messages.group_by { |_key, message| message.exchange_name }.each do |exchange_name, key_message_pairs|
                    process_batch_of_messages(@channel, exchange_name, key_message_pairs)
                  end
                rescue *NETWORK_ERRORS
                  # Sleep because connection is down
                  await_network_reconnect

                rescue => unknown_error
                  ::ActivePublisher.configuration.error_handler.call(unknown_error, {})

                  # TODO: Find a way to bubble this out of the thread for logging purposes.
                  # Reraise the error out of the publisher loop. The Supervisor will restart the consumer.
                  raise unknown_error
                end
              end
            rescue => e
              ::ActivePublisher.configuration.error_handler.call(e, {})
            end
          end
        end

        def wait_for_confirms(channel, messages)
          return true unless channel.using_publisher_confirms?
          if channel.method(:wait_for_confirms).arity > 0
            channel.wait_for_confirms(::ActivePublisher.configuration.publisher_confirms_timeout)
          else
            channel.wait_for_confirms
          end
        end
      end
    end
  end
end
