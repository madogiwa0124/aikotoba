# frozen_string_literal: true

class Aikotoba::RecoverableConstraint
  def self.matches?(_request)
    Aikotoba.enable_recover
  end
end
