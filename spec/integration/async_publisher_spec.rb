require "spec_helper"

describe "an asynchronous publish", :integration => true do
  let(:exchange_name) { "actions" }
  let(:payload) { "Caught a Crim!" }
  let(:route) { "dog.bounty.update" }

  it "publishes a message to rabbitmq" do
    setup_subscriber(exchange_name, route) do |message|
      $message = message
    end
    ::ActivePublisher.publish_async(route, payload, exchange_name)
    verify_expectation_within(1.0) do
      expect($message).to eq({:routing_key => route, :payload => payload})
    end
  end
end
