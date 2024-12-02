require "spec_helper"

describe ::ActivePublisher::Async::InMemoryAdapter::AsyncQueue do
  let(:route) { "test" }
  let(:payload) { "a" * (::ActivePublisher.configuration.max_message_bytes + 1) }
  let(:exchange_name) { "place" }
  let(:options) { { :test => :ok } }
  let(:message) { ::ActivePublisher::Message.new(route, payload, exchange_name, options) }
  let(:mock_queue) { double(:push => nil, :size => 0) }

  subject { described_class.new(:raise, 1, 1) }

  describe "#push" do
    context "when the messsage payload is larger than max_message_bytes" do
      it "raises an error" do
        expect { subject.push(message) }.to raise_error(ActivePublisher::Async::InMemoryAdapter::UnableToPersistMessageError)
      end
    end
  end
end
