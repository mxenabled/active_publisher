require "json"

module ActivePublisher
  module Adapters
    class JSON
      def self.serialize(object)
        object.to_json
      end
    end
  end
end
