require "securerandom"

module ActivePublisher
  class Message < Struct.new(:route, :payload, :exchange_name, :options, :uuid)
    def initialize(*args)
      super
      @uuid = ::SecureRandom.uuid # Set Unique identifier
    end
  end
end
