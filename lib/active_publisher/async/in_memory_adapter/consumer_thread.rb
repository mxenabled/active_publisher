module ActivePublisher
  module Async
    module InMemoryAdapter
      class ConsumerThread
        attr_reader :channel, :thread, :queue, :sampled_queue_size, :last_tick_at

        if ::RUBY_PLATFORM == "java"
          CHANNEL_CLOSED_ERRORS = [::MarchHare::ChannelAlreadyClosed]
        else
          CHANNEL_CLOSED_ERRORS = [::Bunny::ChannelAlreadyClosed]
        end

        if ::RUBY_PLATFORM == "java"
          NETWORK_ERRORS = [::MarchHare::NetworkException, ::MarchHare::ConnectionRefused,
                            ::Java::ComRabbitmqClient::AlreadyClosedException, ::Java::JavaIo::IOException].freeze
        else
          NETWORK_ERRORS = [::Bunny::NetworkFailure, ::Bunny::TCPConnectionFailed, ::Bunny::ConnectionTimeout,
                            ::Timeout::Error, ::IOError].freeze
        end

        if ::RUBY_PLATFORM == "java"
          PRECONDITION_ERRORS = [::MarchHare::PreconditionFailed]
        else
          PRECONDITION_ERRORS = [::Bunny::PreconditionFailed]
        end

        def initialize(listen_queue)
          @queue = listen_queue
          @sampled_queue_size = queue.size

          update_last_tick_at
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

        def cleanup_up_channel
          return if @channel.nil?
          @channel.close
        rescue => error
          ::ActivePublisher.configuration.error_handler.call(error, {:status => "Cleaning up the channel"})
        end

        def handle_current_messages_on_unknown_error(current_messages)
          current_messages.each do |message|
            # Degrade to single message publish ... or at least attempt to
            begin
              ::ActivePublisher.publish(message.route, message.payload, message.exchange_name, message.options)
              current_messages.delete(message)
            rescue *CHANNEL_CLOSED_ERRORS
              # If the channel is bad, raise!
              raise
            rescue *PRECONDITION_ERRORS => error
              # Delete messages if rabbitmq cannot declare the exchange (or somet other precondition failed).
              ::ActivePublisher.configuration.error_handler.call(error, {:reason => "precondition failed", :message => message})
              current_messages.delete(message)
            rescue => other_error
              ::ActivePublisher.configuration.error_handler.call(other_error, {:route => message.route, :payload => message.payload, :exchange_name => message.exchange_name, :options => message.options})
            end
          end
        end

        def make_channel
          channel = ::ActivePublisher::Async::InMemoryAdapter::Channel.new
          channel.confirm_select if ::ActivePublisher.configuration.publisher_confirms
          channel
        end

        def update_last_tick_at
          @last_tick_at = ::Time.now
        end

        def start_thread
          return if alive?
          @thread = ::Thread.new { start_consuming_thread }
        end

        def start_consuming_thread
          loop do
            # Sample the queue size so we don't shutdown when messages are in flight.
            @sampled_queue_size = queue.size
            current_messages = queue.pop_up_to(50, :timeout => 0.1)
            update_last_tick_at
            # If the queue is empty, we should continue to update to "last_tick_at" time.
            next if current_messages.nil?

            @channel ||= make_channel

            # We only look at active publisher messages. Everything else is dropped.
            current_messages.select! { |message| message.is_a?(::ActivePublisher::Message) }

            begin
              # Only open a single connection for each group of messages to an exchange
              current_messages.group_by(&:exchange_name).each do |exchange_name, messages|
                publish_all(@channel, exchange_name, messages)
                current_messages -= messages
              end
            rescue *CHANNEL_CLOSED_ERRORS
              # If the channel is bad, raise without sending one-by-one!
              raise
            rescue *NETWORK_ERRORS
              # Sleep because connection is down
              await_network_reconnect
            rescue => unknown_error
              ::ActivePublisher.configuration.error_handler.call(unknown_error, {:number_of_messages => current_messages.size})

              # Attempt to deliver a message one-by-one. Raise if a closed channel error appears.
              handle_current_messages_on_unknown_error(current_messages)

              # TODO: Find a way to bubble this out of the thread for logging purposes.
              # Reraise the error out of the publisher loop. The Supervisor will restart the consumer.
              raise unknown_error
            ensure
              # Always requeue anything that gets stuck.
              queue.concat(current_messages) if current_messages && !current_messages.empty?
            end
          end
        ensure
          cleanup_up_channel
        end

        def publish_all(channel, exchange_name, messages)
          exchange = channel.topic(exchange_name)
          messages.each do |message|
            fail ::ActivePublisher::ExchangeMismatchError, "bulk publish messages must match publish_all exchange_name" if message.exchange_name != exchange_name
            ::ActiveSupport::Notifications.instrument "message_published.active_publisher", :route => message.route, :message_count => 1 do
              options = ::ActivePublisher.publishing_options(message.route, message.options || {})
              exchange.publish(message.payload, options)
            end
          end
          wait_for_confirms(channel)
        end

        def wait_for_confirms(channel)
          return true unless channel.using_publisher_confirms?
          channel.wait_for_confirms(::ActivePublisher.configuration.publisher_confirms_timeout)
        end
      end
    end
  end
end
