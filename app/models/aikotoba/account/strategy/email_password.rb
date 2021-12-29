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

      def self.confirmable?
        true
      end

      def self.lockable?
        true
      end

      def initialize(email, password)
        @email, @password = email, password
        raise InvalidAttributeError, "EmailPassword requires an email and password." if [@email, @password].any?(&:nil?)
      end

      def build_account
        Aikotoba::Account.new(email: @email, password: @password).tap do |resource|
          resource.strategy = :email_password
          password_digest = build_digest(resource.password)
          resource.assign_attributes(password_digest: password_digest)
        end
      end

      def find_account
        account = Aikotoba::Account.authenticatable.email_password.find_by(email: @email)
        account if account && password_match?(account, @password)
      end

      private

      def password_match?(account, password)
        Argon2::Password.verify_password(password_with_pepper(password), account.password_digest)
      end

      def build_digest(password)
        generate_hash(password_with_pepper(password))
      end

      def password_with_pepper(password)
        "#{password}-#{Aikotoba.password_pepper}"
      end

      def generate_hash(password)
        argon = Argon2::Password.new(t_cost: Aikotoba.password_stretch)
        argon.create(password)
      end
    end
  end
end
