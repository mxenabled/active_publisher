describe ::ActivePublisher::Configuration do
  describe "default values" do
    specify { expect(subject.heartbeat).to eq(5) }
    specify { expect(subject.host).to eq("localhost") }
    specify { expect(subject.hosts).to eq(["localhost"]) }
    specify { expect(subject.port).to eq(5672) }
    specify { expect(subject.timeout).to eq(1) }
  end

  it "logs errors with the default error handler" do
    error = ::RuntimeError.new("ohai")
    expect(::ActivePublisher::Logging.logger).to receive(:error).with(::RuntimeError)
    expect(::ActivePublisher::Logging.logger).to receive(:error).with(error.message)

    ::ActivePublisher.configuration.error_handler.call(error, {})
  end
end
