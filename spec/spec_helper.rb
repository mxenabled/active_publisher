$LOAD_PATH.unshift File.expand_path("../../lib", __FILE__)
require "active_publisher"
require "support/setup_subscriber"
require "fakeredis/rspec"
require "active_publisher/async/redis_adapter"
require "connection_pool"
require "pry"

::ActivePublisher::Async.publisher_adapter = ::ActivePublisher::Async::InMemoryAdapter::Adapter.new
# Silence the logger
$TESTING = true
::ActivePublisher::Logging.initialize_logger(nil)

def verify_expectation_within(number_of_seconds, check_every = 0.02)
  waiting_since = ::Time.now
  begin
    sleep check_every
    yield
  rescue ::RSpec::Expectations::ExpectationNotMetError => e
    if ::Time.now - waiting_since > number_of_seconds
      raise e
    else
      retry
    end
  end
end
