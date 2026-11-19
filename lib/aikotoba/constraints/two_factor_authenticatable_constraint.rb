# frozen_string_literal: true

# NOTE: Per scope, unlike the other feature constraints. The scope is looked up on every
#       request rather than captured when the routes are drawn, so a change to the scope's
#       setting after the routes are drawn (or a configuration swapped in by a test) applies.
#       With strategy:, matches only while the scope offers that strategy (the TOTP set up
#       pages for scopes listing :totp).
class Aikotoba::TwoFactorAuthenticatableConstraint
  def initialize(scope_name, strategy: nil)
    @scope_name = scope_name
    @strategy = strategy&.to_s
  end

  def matches?(_request)
    scope = Aikotoba.scopes[@scope_name]
    return false unless scope&.two_factor_authenticatable?

    @strategy.nil? || scope.two_factor_strategies.include?(@strategy)
  end
end
