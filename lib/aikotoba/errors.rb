module Aikotoba
  module Errors
    class Base < StandardError; end

    class NotAvailableException < Base; end

    class InvalidScopeConfiguration < Base; end

    # NOTE: aikotoba_sign_in was called in a scope that requires a second factor without
    #       saying it was passed (two_factor: :verified). Raised rather than logged, since
    #       signing in anyway would let the caller skip the second factor without anyone noticing.
    class TwoFactorRequired < Base; end
  end
end
