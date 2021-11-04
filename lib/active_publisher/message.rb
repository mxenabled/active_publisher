require "json"
module ActivePublisher
  class Message < Struct.new(:route, :payload, :exchange_name, :options)
    class << self
      def from_json(payload)
        parsed = JSON.load(payload)
        self.new(
          parsed["route"],
          parsed["payload"],
          parsed["exchange_name"],
          parsed["options"],
        )
      end
    end

    def to_json
      self.to_h.to_json
    end
  end
end
