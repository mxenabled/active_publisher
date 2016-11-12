describe ::ActivePublisher::Async do
  before { described_class.instance_variable_set(:@publisher_adapter, nil) }
  after { ::ActivePublisher::Async.publisher_adapter = ::ActivePublisher::Async::InMemoryAdapter::Adapter.new }

  let(:mock_adapter) { double(:publish => nil) }

  describe ".publish_async" do
    before { allow(described_class).to receive(:publisher_adapter).and_return(mock_adapter) }

    it "calls through the adapter" do
      expect(mock_adapter).to receive(:publish).with("1", "2", "3", { "four" => "five" })
      ::ActivePublisher.publish_async("1", "2", "3", { "four" => "five" })
    end
  end

  context "when an in-memory adapter is selected" do
    before { ::ActivePublisher::Async.publisher_adapter = ::ActivePublisher::Async::InMemoryAdapter::Adapter.new }

    it "Creates an in-memory publisher" do
      expect(described_class.publisher_adapter).to be_an(::ActivePublisher::Async::InMemoryAdapter::Adapter)
    end
  end
end
