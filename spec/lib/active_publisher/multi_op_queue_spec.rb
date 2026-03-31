require 'spec_helper'

describe ::ActivePublisher::MultiOpQueue::Queue do
  before do
    @queue = ::ActivePublisher::MultiOpQueue::Queue.new
  end

  describe "#concat" do
    it "pushes all of the array elements onto the queue" do
      @queue.concat([1, 2, 3])
      expect(@queue.size).to eq(3)
    end

    it "keeps the order for pop of the array" do
      @queue.concat([1, 2, 3])
      expect(@queue.pop).to eq(1)
      expect(@queue.pop).to eq(2)
      expect(@queue.pop).to eq(3)
    end
  end

  describe "#size" do
    it "returns 0 when queue is empty" do
      expect(@queue.size).to eq(0)
    end

    it "returns the number of items present when queue is not empty" do
      @queue.push(1)
      @queue.push(1)
      @queue.push(1)
      @queue.push(1)
      @queue.push(1)
      expect(@queue.size).to eq(5)
    end
  end

  describe "#pop_up_to" do
    it "returns an array of 1 element when 1 element present" do
      @queue.push(1)
      expect(@queue.pop_up_to).to eq([1])
    end

    it "returns an array of the pop_up_to number when present" do
      @queue.push(1)
      @queue.push(1)
      @queue.push(1)
      @queue.push(1)
      @queue.push(1)

      expect(@queue.pop_up_to(3)).to eq([1, 1, 1])
    end

    it "supports an optional timeout" do
      start = Time.now.to_f
      expect(@queue.pop_up_to(5, timeout: 0.1)).to be_nil
      expect(Time.now.to_f - start).to be_within(0.01).of(0.1)
    end

    it "blocks until items are available" do
      start = Time.now.to_f
      Thread.new { sleep 0.1; @queue.push(3) }
      expect(@queue.pop_up_to(5, timeout: 0.5)).to eq([3])
      expect(Time.now.to_f - start).to be_within(0.01).of(0.1)
    end
  end
end