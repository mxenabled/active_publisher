require "json"

module ActivePublisher
  module Adapters
    class JSON
      def self.serialize(object)
        JSON.generate(object)
      end
    end
  end
end
