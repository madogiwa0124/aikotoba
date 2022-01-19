# frozen_string_literal: true

class Aikotoba::RegisterableConstraint
  def self.matches?(_request)
    Aikotoba.enable_register
  end
end
