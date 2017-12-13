# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'active_publisher/version'

Gem::Specification.new do |spec|
  spec.name          = "active_publisher"
  spec.version       = ActivePublisher::VERSION
  spec.authors               = ["Brian Stien","Adam Hutchison","Brandon Dewitt","Devin Christensen","Michael Ries"]
  spec.email                 = ["brianastien@gmail.com","liveh2o@gmail.com","brandonsdewitt@gmail.com","quixoten@gmail.com","michael@riesd.com"]
  spec.description           = %q{A library for publshing messages to RabbitMQ}
  spec.summary               = %q{Aims to make publishing work across MRI and jRuby painless and add some nice features like automatially publishing lifecycle events for ActiveRecord models.}
  spec.homepage              = "https://github.com/mxenabled/active_publisher"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]


  if ENV['PLATFORM'] == "java" || ::RUBY_PLATFORM == 'java'
    spec.platform = "java"
    spec.add_dependency 'march_hare', '~> 2.7'
  else
    spec.add_dependency 'bunny', '~> 2.1'
  end

  spec.add_dependency 'activesupport', '>= 3.2'
  spec.add_dependency 'multi_op_queue', '>= 0.1.2'
  spec.add_dependency 'concurrent-ruby'

  spec.add_development_dependency "bundler"
  spec.add_development_dependency "pry"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.2"
end
