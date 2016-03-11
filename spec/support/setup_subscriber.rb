def setup_subscriber(exchange_name, route)
  connection = ::ActivePublisher::Connection.connection
  channel = connection.create_channel
  exchange = channel.topic(exchange_name)

  if ::RUBY_PLATFORM == "java"
    channel.queue("").bind(exchange, :routing_key => route).subscribe do |metadata, payload|
      message = {:routing_key => metadata.routing_key, :payload => payload}
      yield message
    end
  else
    channel.queue("").bind(exchange, :routing_key => route).subscribe do |delivery_info, _, payload|
      message = {:routing_key => delivery_info.routing_key, :payload => payload}
      yield message
    end
  end
end
