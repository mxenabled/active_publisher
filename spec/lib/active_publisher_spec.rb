describe ::ActivePublisher do
  PUBLISH_OPTIONS = {:persistent => true}.freeze
  let(:exchange) { double("Rabbit Exchange") }
  let(:exchange_name) { "events" }
  let(:payload) { "Yo Dawg" }
  let(:route) { "bob.users.created" }

  before { allow(described_class).to receive(:with_exchange).with(exchange_name).and_yield(exchange) }

  describe ".publish_all" do
    it "raises an error if the messages array are not Message objects" do
      expect { described_class.publish_all(exchange_name, [1, 2, 3]) }.to raise_error(ActivePublisher::UnknownMessageClassError)
    end

    it "raises an error if the messages are meant for a different exchange" do
      messages = [
        ActivePublisher::Message.new(route, payload, "something else"),
      ]

      expect { described_class.publish_all(exchange_name, messages) }.to raise_error(ActivePublisher::ExchangeMismatchError)
    end

    it "publishes to a single connection the messages" do
      expect(exchange).to receive(:publish).twice
      messages = [
        ActivePublisher::Message.new(route, payload, exchange_name),
        ActivePublisher::Message.new(route, payload, exchange_name),
      ]

      described_class.publish_all(exchange_name, messages)
    end
  end

  describe '.publish' do
    if ::RUBY_PLATFORM == "java"
      it "publishes to the exchange with default options for march_hare" do
        expect(exchange).to receive(:publish) do |published_payload, published_options|
          expect(published_payload).to eq(payload)
          expect(published_options[:routing_key]).to eq(route)
          expect(published_options[:mandatory]).to eq(false)
          expect(published_options[:properties][:persistent]).to eq(true)
        end

        described_class.publish(route, payload, exchange_name, PUBLISH_OPTIONS)
      end
    else
      it "publishes to the exchange with default options for bunny" do
        expect(exchange).to receive(:publish) do |published_payload, published_options|
          expect(published_payload).to eq(payload)
          expect(published_options[:routing_key]).to eq(route)
          expect(published_options[:persistent]).to eq(true)
          expect(published_options[:mandatory]).to eq(false)
        end

        described_class.publish(route, payload, exchange_name, PUBLISH_OPTIONS)
      end
    end
  end
end
