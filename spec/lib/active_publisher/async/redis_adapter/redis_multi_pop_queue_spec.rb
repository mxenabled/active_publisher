describe ::ActivePublisher::Async::RedisAdapter::RedisMultiPopQueue do
  let(:list_key) { ::ActivePublisher::Async::RedisAdapter::REDIS_LIST_KEY }
  let(:redis_pool) { ::ConnectionPool.new(:size => 5) { ::Redis.new } }
  subject { described_class.new(redis_pool, list_key) }

  describe "initialize with a redis_pool and list_key" do
    it "takes 2 arguments to initialize" do
      expect { described_class.new }.to raise_error(ArgumentError)
      expect { described_class.new(redis_pool) }.to raise_error(ArgumentError)
      expect { described_class.new(redis_pool, "key") }.to_not raise_error
    end
  end

  describe "#empty?" do
    it "is true when nothing has been inserted" do
      expect(subject.empty?).to be true
    end

    it "is false when a single item is inserted to the list_key List" do
      redis_pool.with do |redis|
        redis.lpush(list_key, "derp")
      end

      expect(subject.empty?).to be false
    end

    it "is false when ten items are inserted to the list_key List" do
      redis_pool.with do |redis|
        10.times do 
          redis.lpush(list_key, "derp")
        end
      end

      expect(subject.empty?).to be false
    end
  end

  describe "#pop_up_to" do
    it "is nil when nothing has been inserted" do
      expect(subject.pop_up_to(100, :timeout => 0.1)).to be_nil
    end

    it "returns 1 item when a single item is inserted to the list_key List" do
      redis_pool.with do |redis|
        redis.lpush(list_key, ::Marshal.dump("derp"))
      end

      expect(subject.pop_up_to(100)).to eq(["derp"])
    end

    it "is 10 when ten items are inserted to the list_key List" do
      redis_pool.with do |redis|
        10.times do 
          redis.lpush(list_key, ::Marshal.dump("derp"))
        end
      end

      expect(subject.pop_up_to(100)).to eq([
        "derp",
        "derp",
        "derp",
        "derp",
        "derp",
        "derp",
        "derp",
        "derp",
        "derp",
        "derp",
      ])
    end
  end

  describe "#shift" do
    it "is [] when nothing has been inserted" do
      expect(subject.shift(100)).to eq([])
    end

    it "returns 1 item when a single item is inserted to the list_key List" do
      redis_pool.with do |redis|
        redis.lpush(list_key, ::Marshal.dump("derp"))
      end

      expect(subject.shift(100)).to eq(["derp"])
    end

    it "is 10 when ten items are inserted to the list_key List" do
      redis_pool.with do |redis|
        10.times do 
          redis.lpush(list_key, ::Marshal.dump("derp"))
        end
      end

      expect(subject.shift(100)).to eq([
        "derp",
        "derp",
        "derp",
        "derp",
        "derp",
        "derp",
        "derp",
        "derp",
        "derp",
        "derp",
      ])
    end
  end

  describe "#size" do
    it "is 0 when nothing has been inserted" do
      expect(subject.size).to be 0
    end

    it "is 1 when a single item is inserted to the list_key List" do
      redis_pool.with do |redis|
        redis.lpush(list_key, "derp")
      end

      expect(subject.size).to be 1
    end

    it "is 10 when ten items are inserted to the list_key List" do
      redis_pool.with do |redis|
        10.times do 
          redis.lpush(list_key, "derp")
        end
      end

      expect(subject.size).to be 10
    end
  end

end
