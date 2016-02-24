require "yaml"

module ActivePublisher
  class Configuration
    attr_accessor :async_publisher,
                  :async_publisher_drop_messages_when_queue_full,
                  :async_publisher_max_queue_size,
                  :async_publisher_supervisor_interval,
                  :async_publisher_error_handler,
                  :heartbeat,
                  :host,
                  :hosts,
                  :password,
                  :port,
                  :publisher_confirms,
                  :seconds_to_wait_for_graceful_shutdown,
                  :username,
                  :timeout,
                  :virtual_host

    CONFIGURATION_MUTEX = ::Mutex.new

    DEFAULTS = {
      :async_publisher => 'memory',
      :async_publisher_drop_messages_when_queue_full => false,
      :async_publisher_max_queue_size => 1_000_000,
      :async_publisher_supervisor_interval => 200, # in milliseconds
      :heartbeat => 5,
      :host => 'localhost',
      :hosts => [],
      :port => 5672,
      :publisher_confirms => false,
      :seconds_to_wait_for_graceful_shutdown => 30,
      :timeout => 1,
      :username => "guest",
      :password => "guest",
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

          yaml_config = {}
          absolute_config_path = ::File.expand_path(::File.join("config", "active_publisher.yml"))
            action_subscriber_config_file = ::File.expand_path(::File.join("config", "action_subscriber.yml"))
          if ::File.exists?(absolute_config_path)
            yaml_config = ::YAML.load_file(absolute_config_path)[env]
          elsif ::File.exists?(action_subscriber_config_file)
            yaml_config = ::YAML.load_file(action_subscriber_config_file)[env]
          end

          DEFAULTS.each_pair do |key, value|
            setting = cli_options[key] || yaml_config[key.to_s]
            ::ActivePublisher.config.__send__("#{key}=", setting) if setting
          end

          true
        end
      end
    end

    ##
    # Instance Methods
    #
    def initialize
      self.async_publisher_error_handler = lambda { |error, env_hash| raise error }

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
