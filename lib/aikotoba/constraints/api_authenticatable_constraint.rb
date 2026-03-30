# frozen_string_literal: true

class Aikotoba::ApiAuthenticatableConstraint
  def self.matches?(_request)
    Aikotoba.api_authenticatable
  end
end
