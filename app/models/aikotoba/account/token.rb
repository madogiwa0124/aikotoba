# frozen_string_literal: true

module Aikotoba
  class Account::Token
    # NOTE: The token is 256 bits of SecureRandom output, so a plain SHA-256 is enough to
    #       make a leaked digest useless: there is nothing to brute force, so no salt or slow
    #       hash (cf. PasswordHash's Argon2) is needed, and the digest stays deterministic so it
    #       can be looked up by a unique index.
    def self.digest(value)
      OpenSSL::Digest::SHA256.hexdigest(value)
    end

    def initialize(expiry:)
      @value = build_token
      @expired_at = expiry.since
    end

    attr_reader :value, :expired_at

    def digest
      self.class.digest(value)
    end

    private

    def build_token
      SecureRandom.urlsafe_base64(32)
    end
  end
end
