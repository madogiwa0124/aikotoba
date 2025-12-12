# frozen_string_literal: true

module Aikotoba
  class Account::Token
    def initialize(expiry:)
      @value = build_token
      @expired_at = expiry.since
    end

    attr_reader :value, :expired_at

    private

    def build_token
      SecureRandom.urlsafe_base64(32)
    end
  end
end
