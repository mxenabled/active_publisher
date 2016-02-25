describe ::ActivePublisher::Publishable do

  describe ".exchange" do
    it "is defaults to the default exchange " do
      subject = ::User.new
      expect(subject.exchange).to eq(::ActivePublisher.configuration.default_exchange)
    end
    it "allows an exchange to be set manually" do
      subject = ::User.new
      subject.exchange = :test
      expect(subject.exchange).to eq(:test)
    end
  end
end
