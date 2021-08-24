require 'thread'

module ActivePublisher
  module Connection
    CONNECTION_MUTEX = ::Mutex.new

    def self.connected?
      connection.try(:connected?)
    end

    def self.connection
      CONNECTION_MUTEX.synchronize do
        # Connection must be a valid object and connected. Otherwise, reconnect.
        return @connection if @connection && @connection.connected?
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
    rescue Timeout::Error
      # No-op ... this happens sometimes on MRI disconnect
    end

    # Private API
    def self.create_connection
      if ::RUBY_PLATFORM == "java"
        connection = ::MarchHare.connect(connection_options)
        connection.on_blocked do |reason|
          on_blocked(reason)
        end
        connection.on_unblocked do
          on_unblocked
        end
        connection
      else
        connection = ::Bunny.new(connection_options)
        connection.start
        connection.on_blocked do |blocked_message|
          on_blocked(blocked_message.reason)
        end
        connection.on_unblocked do
          on_unblocked
        end
        connection
      end
    end
    private_class_method :create_connection

    def self.connection_options
      {
        :automatically_recover         => true,
        :continuation_timeout          => ::ActivePublisher.configuration.timeout * 1_000.0, #convert sec to ms
        :heartbeat                     => ::ActivePublisher.configuration.heartbeat,
        :hosts                         => ::ActivePublisher.configuration.hosts,
        :network_recovery_interval     => ::ActivePublisher.configuration.network_recovery_interval,
        :pass                          => ::ActivePublisher.configuration.password,
        :port                          => ::ActivePublisher.configuration.port,
        :recover_from_connection_close => true,
        :tls                           => ::ActivePublisher.configuration.tls,
        :tls_ca_certificates           => ::ActivePublisher.configuration.tls_ca_certificates,
        :tls_cert                      => ::ActivePublisher.configuration.tls_cert,
        :tls_key                       => ::ActivePublisher.configuration.tls_key,
        :user                          => ::ActivePublisher.configuration.username,
        :verify_peer                   => ::ActivePublisher.configuration.verify_peer,
      }
    end
    private_class_method :connection_options

    def self.on_blocked(reason)
      ::ActiveSupport::Notifications.instrument("connection_blocked.active_publisher", :reason => reason)
    end
    private_class_method :on_blocked

    def self.on_unblocked
      ::ActiveSupport::Notifications.instrument("connection_unblocked.active_publisher")
    end
    private_class_method :on_unblocked
  end
end
