require "spec_helper"

describe ::ActivePublisher::Async::InMemoryAdapter::Channel do
  describe "#topic" do
    it "caches a declared topic exchange" do
      exchange1 = subject.topic("asnyc_publisher_testing.random_topic_exchange")
      exchange2 = subject.topic("asnyc_publisher_testing.random_topic_exchange")

      expect(exchange1.__id__).to eq(exchange2.__id__)
    end
  end

  describe "#close" do
    it "proxies the close call" do
      expect(subject.rabbit_channel).to receive(:close)
      subject.close
    end
  end

  describe "#using_publisher_confirms?" do
    it "proxies the using_publisher_confirms? call" do
      expect(subject.using_publisher_confirms?).to eq(false)
      subject.confirm_select
      expect(subject.using_publisher_confirms?).to eq(true)
    end
  end

  describe "#wait_for_confirms" do
    it "proxies the wait_for_confirms call" do
      expect(subject.rabbit_channel).to receive(:wait_for_confirms)
      subject.wait_for_confirms(1)
    end
  end
end
