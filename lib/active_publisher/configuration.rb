module ActivePublisher
  class Configuration
    attr_accessor :application_name, 
                  :default_exchange,
                  :error_handler,
                  :heartbeat,
                  :host,
                  :hosts,
                  :port,
                  :publisher_confirms,
                  :serializer,
                  :timeout,

    def initialize
      self.application_name = 'application_name_not_configured'
      self.serializer = ::ActivePublisher::Adapters::JSON
      self.default_exchange = 'events'
      self.error_handler = lambda { |error, env_hash| raise }
      self.heartbeat = 5
      self.host = 'localhost'
      self.hosts = []
      self.port = 5672
      self.publisher_confirms = false
      self.timeout = 1
    end

    def hosts
      return @hosts if @hosts.size > 0
      [ host ]
    end
  end
end
