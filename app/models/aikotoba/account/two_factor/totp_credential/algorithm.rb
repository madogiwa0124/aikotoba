# frozen_string_literal: true

module Aikotoba
  # NOTE: TOTP itself (RFC 6238), done by the rotp gem: checking a code, the otpauth:// URI an
  #       authenticator app reads, and the code for a given time. TotpCredential uses it by
  #       default and takes another class answering the same methods as algorithm_class:, as
  #       Account::PasswordHash does with Argon2. Named for its role rather than the gem (or the
  #       algorithm, which TOTP fixes): what can be swapped is the library.
  #       The gem isn't an Aikotoba dependency (an app offering TOTP adds it) and app/models is
  #       eager loaded, so it is only required here, once TOTP is actually used.
  class Account::TwoFactor::TotpCredential::Algorithm
    def initialize(secret:, issuer:)
      require "rotp"
      @totp = ROTP::TOTP.new(secret, issuer: issuer)
    end

    # NOTE: The start of the time step (Unix seconds) the code belongs to, when it matches one
    #       of the steps within drift seconds of at and is later than after's step; nil
    #       otherwise.
    def verify(code, drift:, after:, at:)
      @totp.verify(code, drift_behind: drift, drift_ahead: drift, after: after, at: at)
    end

    def provisioning_uri(account_name)
      @totp.provisioning_uri(account_name)
    end

    # NOTE: The code an authenticator app shows at time (used by the test helpers).
    def generate_code(at:)
      @totp.at(at)
    end
  end
end
