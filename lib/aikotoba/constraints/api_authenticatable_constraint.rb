# frozen_string_literal: true

class Aikotoba::Api::AuthenticatableConstraint
  def self.matches?(_request)
    Aikotoba.api_authenticatable
  end
end
