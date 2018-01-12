describe ::ActivePublisher::Async::RedisAdapter::Adapter do
  subject { described_class.new(redis_pool) }
  let(:route) { "test" }
  let(:payload) { "payload" }
  let(:exchange_name) { "place" }
  let(:options) { { :flush_queue => true, :test => :ok } }
  let(:message) { ::ActivePublisher::Message.new(route, payload, exchange_name, options) }
  let(:redis_pool) { ::ConnectionPool.new(:size => 5) { ::Redis.new } }

  describe "#publish" do
    before do
      allow(ActivePublisher::Message).to receive(:new).with(route, payload, exchange_name, options).and_return(message)
    end

    it "can publish a message to the queue" do
      expect_any_instance_of(::Redis).to receive(:lpush)
      subject.publish(route, payload, exchange_name, options)
    end
  end

  describe "#shutdown!" do
    # This is called when the rspec finishes. I'm sure we can make this a better test.
  end
end
