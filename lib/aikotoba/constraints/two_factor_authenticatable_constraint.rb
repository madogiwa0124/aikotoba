# frozen_string_literal: true

# NOTE: Per scope, unlike the other feature constraints. The scope is looked up on every
#       request rather than captured when the routes are drawn, so a change to the scope's
#       setting after the routes are drawn (or a configuration swapped in by a test) applies.
class Aikotoba::TwoFactorAuthenticatableConstraint
  def initialize(scope_name)
    @scope_name = scope_name
  end

  def matches?(_request)
    Aikotoba.scopes[@scope_name]&.two_factor_authenticatable? || false
  end
end
