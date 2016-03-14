require "spec_helper"

describe "a basic publisher", :integration => true do
  let(:exchange_name) { "events" }
  let(:payload) { "meow" }
  let(:route) { "bob.users.created" }

  it "publishes messages to rabbit" do
    setup_subscriber(exchange_name, route) do |message|
      $message = message
    end
    ::ActivePublisher.publish(route, payload, exchange_name)
    verify_expectation_within(1.0) do
      expect($message).to eq({:routing_key => route, :payload => payload})
    end
  end
end
