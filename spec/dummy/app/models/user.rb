class User < ActiveRecord::Base
  include ActivePublisher::Publishable
end
