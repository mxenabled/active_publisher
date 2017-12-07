describe ::ActivePublisher::Configuration do
  describe "default values" do
    specify { expect(subject.heartbeat).to eq(5) }
    specify { expect(subject.host).to eq("localhost") }
    specify { expect(subject.hosts).to eq(["localhost"]) }
    specify { expect(subject.network_recovery_interval).to eq(1) }
    specify { expect(subject.port).to eq(5672) }
    specify { expect(subject.timeout).to eq(1) }
    specify { expect(subject.tls).to eq(false) }
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

    context "when using a yaml file" do
      let!(:sample_yaml_location) { ::File.expand_path(::File.join("spec", "support", "sample_config.yml")) }

      before { allow(::File).to receive(:expand_path) { sample_yaml_location } }

      it "parses any ERB in the yaml" do
        expect(::ActivePublisher.configuration).to receive(:password=).with("WAT").and_return(true)
        ::ActivePublisher::Configuration.configure_from_yaml_and_cli({}, true)
      end
    end
  end
end
