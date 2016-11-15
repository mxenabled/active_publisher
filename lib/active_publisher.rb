if ::RUBY_PLATFORM == "java"
  require "march_hare"
else
  require "bunny"
end
require "thread"

require "active_publisher/logging"
require "active_publisher/async"
require "active_publisher/async/in_memory_adapter"
require "active_publisher/message"
require "active_publisher/version"
require "active_publisher/configuration"
require "active_publisher/connection"

module ActivePublisher
  class UnknownMessageClassError < StandardError; end

  def self.configuration
    @configuration ||= ::ActivePublisher::Configuration.new
  end

  def self.configure
    yield(configuration) if block_given?
  end

  # Publish a message to RabbitMQ
  #
  # @param [String] route The routing key to use for this message.
  # @param [String] payload The message you are sending. Should already be encoded as a string.
  # @param [String] exchange The exchange you want to publish to.
  # @param [Hash] options hash to set message parameters (e.g. headers)
  def self.publish(route, payload, exchange_name, options = {})
    with_exchange(exchange_name) do |exchange|
      exchange.publish(payload, publishing_options(route, options))
    end
  end

  def self.publish_all(exchange_name, messages)
    with_exchange(exchange_name) do |exchange|
      messages.each do |message|
        fail ActivePublisher::UnknownMessageClassError, "bulk publish messages must be ActivePublisher::Message" unless message.is_a?(ActivePublisher::Message)
        exchange.publish(message.payload, publishing_options(message.route, message.options || {}))
      end
    end
  end

  def self.publishing_options(route, in_options = {})
    options = {
      :mandatory => false,
      :persistent => false,
      :routing_key => route,
    }.merge(in_options)
    
    if ::RUBY_PLATFORM == "java"
      java_options = {}
      java_options[:mandatory]   = options.delete(:mandatory)
      java_options[:routing_key] = options.delete(:routing_key)
      java_options[:properties]  = options
      java_options
    else
      options
    end
  end

  def self.with_exchange(exchange_name)
    connection = ::ActivePublisher::Connection.connection
    channel = connection.create_channel
    begin
      channel.confirm_select if configuration.publisher_confirms
      exchange = channel.topic(exchange_name)
      yield(exchange)
      channel.wait_for_confirms if configuration.publisher_confirms
    ensure
      channel.close rescue nil
    end
  end
end

if defined?(::ActiveSupport)
  ::ActiveSupport.run_load_hooks(:active_publisher)
end

at_exit do
  ::ActivePublisher::Async.publisher_adapter.shutdown! if ::ActivePublisher::Async.publisher_adapter
  ::ActivePublisher::Connection.disconnect!
end
