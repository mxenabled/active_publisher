describe ::ActivePublisher::Async::InMemoryAdapter::Adapter do
  let(:route) { "test" }
  let(:payload) { "payload" }
  let(:exchange_name) { "place" }
  let(:options) { { :test => :ok } }
  let(:message) { ActivePublisher::Message.new(route, payload, exchange_name, options) }
  let(:mock_queue) { double(:push => nil, :size => 0) }

  describe "#publish" do
    before do
      allow(ActivePublisher::Message).to receive(:new).with(route, payload, exchange_name, options).and_return(message)
      allow(ActivePublisher::Async::InMemoryAdapter::AsyncQueue).to receive(:new).and_return(mock_queue)
    end

    it "can publish a message to the queue" do
      expect(mock_queue).to receive(:push).with(message)
      subject.publish(route, payload, exchange_name, options)
    end
  end

  describe "#shutdown!" do
    # This is called when the rspec finishes. I'm sure we can make this a better test.
  end

  describe "::Message" do
    specify { expect(message.route).to eq(route) }
    specify { expect(message.payload).to eq(payload) }
    specify { expect(message.exchange_name).to eq(exchange_name) }
    specify { expect(message.options).to eq(options) }
  end

  describe "::AsyncQueue" do
    subject { ActivePublisher::Async::InMemoryAdapter::AsyncQueue.new(false, 1_000_000, 0.2) }

    describe ".initialize" do
      it "creates a supervisor" do
        expect_any_instance_of(ActivePublisher::Async::InMemoryAdapter::AsyncQueue).to receive(:create_and_supervise_consumer!)
        subject
      end
    end

    describe "#create_and_supervise_consumer!" do
      it "restarts the consumer when it dies" do
        consumer = subject.consumer
        consumer.kill

        verify_expectation_within(0.1) do
          expect(consumer).to_not be_alive
        end

        verify_expectation_within(0.3) do
          expect(subject.consumer).to be_alive
        end
      end
    end

    describe "#create_consumer" do
      it "can successfully publish a message" do
        expect(::ActivePublisher).to receive(:publish).with(route, payload, exchange_name, options)
        subject.push(message)
        sleep 0.1 # Await results
      end

      context "when network error occurs" do
        let(:error) { ActivePublisher::Async::InMemoryAdapter::ConsumerThread::NETWORK_ERRORS.first }
        before { allow(::ActivePublisher).to receive(:publish).and_raise(error) }

        it "requeues the message" do
          consumer = subject.consumer
          expect(consumer).to be_alive
          subject.push(message)
          sleep 0.1 # Await results
        end
      end

      context "when an unknown error occurs" do
        before { allow(::ActivePublisher).to receive(:publish).and_raise(::ArgumentError) }

        it "kills the consumer" do
          consumer = subject.consumer
          expect(consumer).to be_alive
          subject.push(message)
          sleep 0.1 # Await results
          expect(consumer).to_not be_alive
        end
      end
    end

    describe "#push" do
      after { subject.max_queue_size = 1000 }
      after { subject.drop_messages_when_queue_full = false }

      context "when the queue has room" do
        before { allow(Queue).to receive(:new).and_return(mock_queue) }

        it "successfully adds to the queue" do
          expect(mock_queue).to receive(:push).with(message)
          subject.push(message)
        end
      end

      context "when the queue is full" do
        before { subject.max_queue_size = -1 }

        context "and we're dropping messages" do
          before { subject.drop_messages_when_queue_full = true }

          it "adding to the queue should not raise an error" do
            expect { subject.push(message) }.to_not raise_error
          end
        end

        context "and we're not dropping messages" do
          before { subject.drop_messages_when_queue_full = false }

          it "adding to teh queue should raise error back to caller" do
            expect { subject.push(message) }.to raise_error(ActivePublisher::Async::InMemoryAdapter::UnableToPersistMessageError)
          end
        end
      end
    end

    describe "#size" do
      it "can return the size of the queue" do
        expect(subject.size).to eq(0)
      end
    end
  end
end
