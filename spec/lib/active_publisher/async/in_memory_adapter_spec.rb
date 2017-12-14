describe ::ActivePublisher::Async::InMemoryAdapter::Adapter do
  let(:consumer) { subject.consumer }
  let(:route) { "test" }
  let(:payload) { "payload" }
  let(:exchange_name) { "place" }
  let(:options) { { :test => :ok } }
  let(:message) { ActivePublisher::Message.new(route, payload, exchange_name, options) }
  let(:mock_queue) { double(:push => nil, :size => 0) }
  let(:back_pressure_strategy) { :raise }
  let(:max_queue_size) { 100 }

  describe ".new" do
    context "defaults" do
      it "sets a default max queue size" do
        expect(subject.async_queue.max_queue_size).to eq(100_000)
      end

      it "sets a default back pressure strategy" do
        expect(subject.async_queue.back_pressure_strategy).to eq(:raise)
      end

      it "sets a default supervisor interval" do
        expect(subject.async_queue.supervisor_interval).to eq(0.2)
      end
    end
  end

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
    subject { ActivePublisher::Async::InMemoryAdapter::AsyncQueue.new(back_pressure_strategy, max_queue_size, 0.2) }

    describe ".initialize" do
      it "creates a supervisor" do
        expect_any_instance_of(ActivePublisher::Async::InMemoryAdapter::AsyncQueue).to receive(:create_and_supervise_consumer!)
        subject
      end
    end

    describe "#create_and_supervise_consumer!" do
      it "restarts the consumer when it dies" do
        consumer.kill

        verify_expectation_within(0.1) do
          expect(consumer).to_not be_alive
        end

        verify_expectation_within(0.3) do
          expect(subject.consumer).to be_alive
        end
      end

      context "lagging consumer" do
        it "restarts the consumer when it's lagging" do
          allow(consumer).to receive(:last_tick_at).and_return(::Time.now - 20)

          verify_expectation_within(0.5) do
            # Verify a new consumer is created.
            expect(subject.consumer.__id__).to_not eq(consumer.__id__)
          end
        end

        it "updates the last_tick_at time every 100ms" do
          time1 = consumer.last_tick_at

          time2 = nil
          verify_expectation_within(0.5) do
            time2 = consumer.last_tick_at
            expect(time2).to be > time1
          end

          verify_expectation_within(0.5) do
            time3 = consumer.last_tick_at
            expect(time3).to be > time2
          end
        end
      end
    end

    describe "#create_consumer" do
      it "can successfully publish a message" do
        expect(::ActiveSupport::Notifications).to receive(:instrument)
                                                    .with("message_published.active_publisher",:message_count => 1)
        expect(consumer).to receive(:publish_all).with(anything, exchange_name, [message]).and_call_original
        subject.push(message)
        sleep 0.1 # Await results
      end

      context "when network error occurs" do
        let(:error) { ActivePublisher::Async::InMemoryAdapter::ConsumerThread::NETWORK_ERRORS.first }
        before { allow(consumer).to receive(:publish_all).and_raise(error) }

        it "requeues the message" do
          expect(consumer).to be_alive
          subject.push(message)
          sleep 0.1 # Await results
        end
      end

      context "when an unknown error occurs" do
        before { allow(consumer).to receive(:publish_all).and_raise(::ArgumentError) }

        it "kills the consumer" do
          expect(consumer).to be_alive
          subject.push(message)
          verify_expectation_within(0.5) do
            expect(consumer).to_not be_alive
          end
        end
      end
    end

    describe "#push" do
      context "when the queue has room" do
        before { allow(::MultiOpQueue::Queue).to receive(:new).and_return(mock_queue) }

        it "successfully adds to the queue" do
          expect(mock_queue).to receive(:push).with(message)
          subject.push(message)
        end
      end

      context "when the queue is full" do
        let(:max_queue_size) { -1 }

        context "dropping messages" do
          let(:back_pressure_strategy) { :drop }

          it "adding to the queue should not raise an error" do
            expect { subject.push(message) }.to_not raise_error
          end
        end

        context "waiting for space in the queue" do
          let(:back_pressure_strategy) { :wait }

          it "adding to the queue should not raise an error" do
            expect(subject.queue).to receive(:push)
            thread = Thread.new do
              subject.push(message)
            end
            # Ensure the thread is waiting by doing a sleep here and checking thread.alive?
            sleep 0.1
            expect(thread).to be_alive
            subject.max_queue_size = 100
            thread.join
          end
        end

        context "raise errors" do
          it "adding to teh queue should raise error back to caller" do
            expect { subject.push(message) }.to raise_error(ActivePublisher::Async::InMemoryAdapter::UnableToPersistMessageError)
          end
        end

        context "invalid strategy" do
          it "raises an error" do
            expect { subject.back_pressure_strategy = :yolo }.to raise_error("Invalid back pressure strategy: yolo")
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
