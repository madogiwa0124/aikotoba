# frozen_string_literal: true

module Aikotoba
  class Account::Authentication
    def self.call(email:, password:)
      new(email: email, password: password).call
    end

    def initialize(email:, password:)
      @email = email
      @password = password
    end

    def call
      account = find_by_identifier
      account if account && password_match?(account.password_digest)
    end

    private

    def find_by_identifier
      Account.authenticatable.find_by(email: @email)
    end

    def password_match?(password_digest)
      password = Account::Password.new(value: @password)
      password.match?(digest: password_digest)
    end
  end
end
