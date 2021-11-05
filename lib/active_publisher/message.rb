require "base64"
require "json"

module ActivePublisher
  class Message < Struct.new(:route, :payload, :exchange_name, :options)
    class << self
      def from_json(payload)
        parsed = JSON.load(payload)
        self.new(
          parsed["route"],
          Base64.decode64(parsed["payload"]),
          parsed["exchange_name"],
          parsed["options"],
        )
      end
    end

    def to_json
      {
        route: self.route,
        payload: Base64.encode64(self.payload),
        exchange_name: self.exchange_name,
        options: self.options,
      }.to_json
    end
  end
end
