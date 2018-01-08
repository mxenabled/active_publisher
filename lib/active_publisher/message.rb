module ActivePublisher
  class Message < Struct.new(:route, :payload, :exchange_name, :options)
    def initialize(*args)
      super
    end
  end
end
