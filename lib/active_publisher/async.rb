module ActivePublisher
  # Publish a message asynchronously to RabbitMQ.
  #
  # Asynchronous is designed to do two things:
  # 1. Introduce the idea of a durable retry should the RabbitMQ connection disconnect.
  # 2. Provide a higher-level pattern for fire-and-forget publishing.
  #
  # @param [String] route The routing key to use for this message.
  # @param [String] payload The message you are sending. Should already be encoded as a string.
  # @param [String] exchange The exchange you want to publish to.
  # @param [Hash] options hash to set message parameters (e.g. headers).
  def self.publish_async(route, payload, exchange_name, options = {})
    ::ActivePublisher::Async.publisher_adapter.publish(route, payload, exchange_name, options)
  end

  module Async
    class << self
      attr_accessor :publisher_adapter
    end
  end
end

require "active_publisher/async/abstract_queue"
require "active_publisher/async/disk_backed_queue"
