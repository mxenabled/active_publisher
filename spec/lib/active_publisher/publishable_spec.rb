describe ::ActivePublisher::Publishable do

  describe ".exchange" do
    it "is defaults :events" do
      subject = ::User.new
      expect(subject.exchange).to eq(:events)
    end

    it "can be set manually" do
      subject = ::User.new
      subject.exchange = :test
      expect(subject.exchange).to eq(:test)
    end
  end

  describe "after_create_callback" do
    it "it publishes a serialized version of self" do
      publisher = class_double("ActivePublisher").as_stubbed_const(:transfer_nested_constants => true)

      expect(publisher).to receive(:serialize).and_return("dummy_serialized_object")
      expect(publisher).to receive(:publish).with("dummy.user.created", "dummy_serialized_object", :events)
      ::User.create(:email => "test@gmail.com")
    end
  end
end
