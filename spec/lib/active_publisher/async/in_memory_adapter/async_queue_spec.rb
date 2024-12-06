require "spec_helper"

describe ::ActivePublisher::Async::InMemoryAdapter::AsyncQueue do
  let(:route) { "test" }
  let(:payload) { "ab" }
  let(:exchange_name) { "place" }
  let(:options) { { :test => :ok } }
  let(:message) { ::ActivePublisher::Message.new(route, payload, exchange_name, options) }

  subject { described_class.new(:raise, 1, 1) }

  describe "#push" do
    context "when max_payload_bytes is set" do
      before { ::ActivePublisher.configuration.max_payload_bytes = 1 }

      context "message payload bytes is less than or equal to max_payload_bytes" do
        let(:payload) { "a" }

        it "pushes the message to the queue" do
          expect(subject.queue).to receive(:push).with(message)
          subject.push(message)
        end
      end

      context "message payload bytes is greater than max_payload_bytes" do
        it "raises an error" do
          expect { subject.push(message) }.to raise_error(
            ActivePublisher::Async::InMemoryAdapter::MaxPayloadBytesExceeded,
            "Message dropped, the message payload bytes #{message.payload.bytesize} exceeds the ActivePublisher configuration max_payload_bytes #{::ActivePublisher.configuration.max_payload_bytes}. Message attributes minus payload: #{message.to_h.except(:payload)}"
          )
        end
      end
    end

    context "when max_payload_bytes is nil" do
      before do
        ::ActivePublisher.configuration.max_payload_bytes = nil
        allow(subject.queue).to receive(:push).with(message)
      end

      it "bypasses max_payload_bytes_check" do
        expect(message.payload).to_not receive(:bytesize)
        subject.push(message)
      end
    end
  end
end
