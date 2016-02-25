module ActivePublisher
  module Publishable

    def self.included(base)
      base.class_eval do
        after_create  :publish_created_event
        after_destroy :publish_deleted_event
        after_update  :publish_updated_event
      end
    end

    def exchange=(exchange)
      @exchange = exchange
    end

    def exchange
      @exchange || :events #ActivePublisher.configuration.default_exchange
    end

    def routing_key(event_type)
      app_name = Rails.application.class.parent_name.downcase
      "#{app_name}.#{self.class.name.downcase}.#{event_type}"
    end
    
    private 

    def active_publisher_payload
      ::ActivePublisher.serialize(self)
    end

    def publish_created_event
      publish_event(:created)
    end

    def publish_deleted_event
      publish_event(:deleted)
    end

    def publish_event(event_type)
      route = routing_key(event_type)
      ::ActivePublisher.publish(route, active_publisher_payload, exchange)
    end

    def publish_updated_event
      publish_event(:updated)
    end

  end
end
