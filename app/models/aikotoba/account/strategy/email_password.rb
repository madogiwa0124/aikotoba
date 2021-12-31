# frozen_string_literal: true

require "argon2"

module Aikotoba
  module Account::Strategy
    class EmailPassword < Base
      def self.build_account_by(attributes)
        email, password = attributes.values_at(:email, :password)
        new(email, password).build_account
      end

      def self.find_account_by(attributes)
        email, password = attributes.values_at(:email, :password)
        new(email, password).find_account
      end

      def initialize(email, password)
        @email, @password = email, password
        raise InvalidAttributeError, "EmailPassword requires an email and password." if [@email, @password].any?(&:nil?)
      end

      def build_account
        Aikotoba::Account.new(email: @email, password: @password).tap do |resource|
          password_digest = Account::Password.new(value: resource.password).digest
          resource.assign_attributes(password_digest: password_digest)
        end
      end

      def find_account
        account = Aikotoba::Account.authenticatable.find_by(email: @email)
        password = Account::Password.new(value: @password)
        account if account && password.match?(digest: account.password_digest)
      end
    end
  end
end
