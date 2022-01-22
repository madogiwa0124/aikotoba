# frozen_string_literal: true

class Aikotoba::LockableConstraint
  def self.matches?(_request)
    Aikotoba.lockable
  end
end
