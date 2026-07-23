# frozen_string_literal: true

class Aikotoba::MagicLinkAuthenticatableConstraint
  def self.matches?(_request)
    Aikotoba.magic_link_authenticatable
  end
end
