module ActivePublisher
  class Message < Struct.new(:route, :payload, :exchange_name, :options); end
end
