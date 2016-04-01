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

  describe ".configure_from_yaml_and_cli" do
    it "sets configuration values on the shared configuration object" do
      expect(::ActivePublisher.configuration).to receive(:password=).with("WAT").and_return(true)
      ::ActivePublisher::Configuration.configure_from_yaml_and_cli({:password => "WAT"}, true)
    end

    it "looks for string keys as well" do
      expect(::ActivePublisher.configuration).to receive(:password=).with("WAT").and_return(true)
      ::ActivePublisher::Configuration.configure_from_yaml_and_cli({"password" => "WAT"}, true)
    end
  end
end
