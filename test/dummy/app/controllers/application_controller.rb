class ApplicationController < ActionController::Base
  include Aikotoba::Authorizable
  include Aikotoba::Authenticatable
end
