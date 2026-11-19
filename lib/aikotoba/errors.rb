module Aikotoba
  module Errors
    class Base < StandardError; end

    class NotAvailableException < Base; end

    class InvalidScopeConfiguration < Base; end

    # NOTE: aikotoba_sign_in was called in a scope that requires a second factor without
    #       saying it was passed (two_factor: :verified). Raised rather than logged, since
    #       signing in anyway would let the caller skip the second factor without anyone noticing.
    class TwoFactorRequired < Base; end

    # NOTE: A scope's two-factor settings can't work as set (an unknown strategy, or only
    #       strategies that need setting up). Raised at boot by
    #       Account::TwoFactor.validate_configuration!.
    class InvalidTwoFactorConfiguration < Base; end
  end
end
