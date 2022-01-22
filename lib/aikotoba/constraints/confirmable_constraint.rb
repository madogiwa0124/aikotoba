# frozen_string_literal: true

class Aikotoba::ConfirmableConstraint
  def self.matches?(_request)
    Aikotoba.confirmable
  end
end
