require "yaml"
require "erb"

module ActivePublisher
  class Configuration
    attr_accessor :error_handler,
                  :heartbeat,
                  :host,
                  :hosts,
                  :max_async_publisher_lag_time,
                  :messages_per_batch,
                  :network_recovery_interval,
                  :password,
                  :port,
                  :publisher_threads,
                  :publisher_confirms,
                  :publisher_confirms_timeout,
                  :seconds_to_wait_for_graceful_shutdown,
                  :timeout,
                  :tls,
                  :tls_ca_certificates,
                  :tls_cert,
                  :tls_key,
                  :username,
                  :verify_peer,
                  :virtual_host

    CONFIGURATION_MUTEX = ::Mutex.new
    NETWORK_RECOVERY_INTERVAL = 1.freeze

    DEFAULTS = {
      :error_handler => lambda { |error, env_hash|
        ::ActivePublisher::Logging.logger.error(error.class)
        ::ActivePublisher::Logging.logger.error(error.message)
        ::ActivePublisher::Logging.logger.error(error.backtrace.join("\n")) if error.backtrace.respond_to?(:join)
      },
      :heartbeat => 5,
      :host => "localhost",
      :hosts => [],
      :password => "guest",
      :messages_per_batch => 25,
      :max_async_publisher_lag_time => 10,
      :network_recovery_interval => NETWORK_RECOVERY_INTERVAL,
      :port => 5672,
      :publisher_threads => 1,
      :publisher_confirms => false,
      :publisher_confirms_timeout => 5_000, #specified as a number of milliseconds
      :seconds_to_wait_for_graceful_shutdown => 30,
      :timeout => 1,
      :tls => false,
      :tls_ca_certificates => [],
      :tls_cert => nil,
      :tls_key => nil,
      :username => "guest",
      :verify_peer => true,
      :virtual_host => "/"
    }

    ##
    # Class Methods
    #
    def self.configure_from_yaml_and_cli(cli_options = {}, reload = false)
      CONFIGURATION_MUTEX.synchronize do
        @configure_from_yaml_and_cli = nil if reload
        @configure_from_yaml_and_cli ||= begin
          env = ENV["RAILS_ENV"] || ENV["RACK_ENV"] || ENV["APP_ENV"] || "development"

          yaml_config = attempt_to_load_yaml_file(env)
          DEFAULTS.each_pair do |key, value|
            exists, setting = fetch_config_value(key, cli_options, yaml_config)
            ::ActivePublisher.configuration.public_send("#{key}=", setting) if exists
          end

          true
        end
      end
    end

    ##
    # Private class methods
    #
    def self.attempt_to_load_yaml_file(env)
      yaml_config = {}
      absolute_config_path = ::File.expand_path(::File.join("config", "active_publisher.yml"))
      action_subscriber_config_file = ::File.expand_path(::File.join("config", "action_subscriber.yml"))
      if ::File.exists?(absolute_config_path)
        yaml_config = ::YAML.load(::ERB.new(::File.read(absolute_config_path)).result)[env]
      elsif ::File.exists?(action_subscriber_config_file)
        yaml_config = ::YAML.load(::ERB.new(::File.read(action_subscriber_config_file)).result)[env]
      end
      yaml_config
    end
    private_class_method :attempt_to_load_yaml_file

    def self.fetch_config_value(key, cli_options, yaml_config)
      return [true, cli_options[key]] if cli_options.key?(key)
      return [true, cli_options[key.to_s]] if cli_options.key?(key.to_s)
      return [true, yaml_config[key]] if yaml_config.key?(key)
      return [true, yaml_config[key.to_s]] if yaml_config.key?(key.to_s)
      [false, nil]
    end
    private_class_method :fetch_config_value

    ##
    # Instance Methods
    #
    def initialize
      DEFAULTS.each_pair do |key, value|
        self.__send__("#{key}=", value)
      end
    end

    def connection_string=(url)
      settings = ::ActionSubscriber::URI.parse_amqp_url(url)
      settings.each do |key, value|
        send("#{key}=", value)
      end
    end

    def hosts
      return @hosts if @hosts.size > 0
      [ host ]
    end
  end
end
