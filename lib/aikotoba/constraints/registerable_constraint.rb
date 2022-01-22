# frozen_string_literal: true

class Aikotoba::RegisterableConstraint
  def self.matches?(_request)
    Aikotoba.registerable
  end
end
