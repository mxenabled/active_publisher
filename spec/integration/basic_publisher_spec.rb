require "spec_helper"

describe "a basic publisher", :integration => true do
  let(:exchange_name) { "events" }
  let(:payload) { "meow" }
  let(:route) { "bob.users.created" }

  it "publishes messages to rabbit" do
    initialize_subscriber(exchange_name, route)
    ::ActivePublisher.publish(route, payload, exchange_name)
    expect($message).to eq([route, payload])
  end
end

def initialize_subscriber(exchange_name, route)
  connection = ::ActivePublisher::Connection.connection
  channel = connection.create_channel
  exchange = channel.topic(exchange_name)

  if ::RUBY_PLATFORM == "java"
    channel.queue("").bind(exchange, :routing_key => route).subscribe do |metadata, payload|
      $message = [metadata.routing_key, payload]
    end
  else
    channel.queue("").bind(exchange, :routing_key => route).subscribe do |delivery_info, _, payload|
      $message = [delivery_info.routing_key, payload]
    end
  end
end
