require 'thread'

module ActivePublisher
  module Connection
    CONNECTION_MUTEX = ::Mutex.new

    def self.connected?
      connection.try(:connected?)
    end

    def self.connection
      CONNECTION_MUTEX.synchronize do
        return @connection if @connection
        @connection = create_connection
      end
    end

    def self.disconnect!
      CONNECTION_MUTEX.synchronize do
        if @connection && @connection.connected?
          @connection.close
        end

        @connection = nil
      end
    end

    # Private API
    def self.create_connection
      if ::RUBY_PLATFORM == "java"
        connection = ::MarchHare.connect(connection_options)
      else
        connection = ::Bunny.new(connection_options)
        connection.start
        connection
      end
    end
    private_class_method :create_connection

    def self.connection_options
      {
        :heartbeat                     => ::ActivePublisher.configuration.heartbeat,
        :hosts                         => ::ActivePublisher.configuration.hosts,
        :port                          => ::ActivePublisher.configuration.port,
        :continuation_timeout          => ::ActivePublisher.configuration.timeout * 1_000.0, #convert sec to ms
        :automatically_recover         => true,
        :network_recovery_interval     => 1,
        :recover_from_connection_close => true,
      }
    end
    private_class_method :connection_options
  end
end
