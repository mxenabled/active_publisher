module ActivePublisher
  class Configuration
    attr_accessor :default_exchange,
                  :error_handler,
                  :heartbeat,
                  :host,
                  :hosts,
                  :port,
                  :publisher_confirms,
                  :timeout

    def initialize
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
