# ActivePublisher

Welcome to your new gem! In this directory, you'll find the files you need to be able to package up your Ruby library into a gem. Put your Ruby code in the file `lib/active_publisher`. To experiment with that code, run `bin/console` for an interactive prompt.

TODO: Delete this and the text above, and describe your gem

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'active_publisher'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install active_publisher

## Configuration

ActivePublisher will use a `config/active_publisher.yml` or `config/action_subscriber.yml` if you include the line `::ActivePublisher::Configuration.configure_from_yaml_and_cli` in an initializer.

Create a `config/active_publisher.yml` similar to a database.yml, with your configuration nested in your environments keys.

```yaml
default: &default
  host: localhost
  username: guest
  password: guest

development:
  <<: *default

test:
  <<: *default

production:
  <<: *default
  host: <%= ENV['RABBIT_MQ_HOST'] %>
  username: <%= ENV['RABBIT_MQ_USERNAME'] %>
  password: <%= ENV['RABBIT_MQ_PASSWORD'] %>
```

Defaults for the configuration are:
```ruby
{
  :heartbeat => 5,
  :host => "localhost",
  :hosts => [],
  :max_async_publisher_lag_time => 10,
  :network_recovery_interval => 1,
  :password => "guest",
  :port => 5672,
  :publisher_threads => 1,
  :publisher_confirms => false,
  :publisher_confirms_timeout => 5_000,
  :seconds_to_wait_for_graceful_shutdown => 30,
  :timeout => 1,
  :tls => false,
  :tls_ca_certificates => [],
  :tls_cert => nil,
  :tls_key => nil,
  :username => "guest",
  :verify_peer => true,
  :virtual_host => "/"
}
```

## Usage

Basic publishing is simple.

```ruby
  # @param [String] route The routing key to use for this message.
  # @param [String] payload The message you are sending. Should already be encoded as a string.
  # @param [String] exchange The exchange you want to publish to.
  # @param [Hash] options hash to set message parameters (e.g. headers)

  ::ActivePublisher.publish("user.created", user.to_json, "events", {})
```


Async publishing is as simple as configuring the async publishing adapter and running `publish_sync` the same was as publish.
You can use the `::ActivePublisher::Async::InMemoryAdapter` that ships with `ActivePublisher`.


`initializers/active_publisher.rb`
```ruby
require "active_publisher"
::ActivePublisher::Async.publisher_adapter = ::ActivePublisher::Async::InMemoryAdapter.new

```

```ruby
::ActivePublisher.publish_async("user.created", user.to_json, "events", {})
```


## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/active_publisher. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](contributor-covenant.org) code of conduct.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
