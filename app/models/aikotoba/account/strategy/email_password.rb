# frozen_string_literal: true

require 'argon2'

module Aikotoba
  class Account::Strategy::EmailPassword < Account::Strategy::Base
    def self.build_account_by(attributes)
      email, password = attributes.values_at("email", "password")
      new.build_account_by(email: email, password: password)
    end

    def self.find_account_by(credentials)
      email, password = credentials.values_at("email", "password")
      new.find_account_by(email: email, password: password)
    end

    def self.confirmable?
      true
    end

    def build_account_by(email:, password:)
      build_with_email_password(email, password)
    end

    def find_account_by(email:, password:)
      account = find_by_email(email)
      account if password_match?(account, password)
    end

    private

    def find_by_email(email)
      Aikotoba::Account.authenticatable.email_password.find_by(email: email)
    end

    def password_match?(account, password)
      return false unless account
      Argon2::Password.verify_password(password_with_papper(password), account.password_digest)
    end

    def build_with_email_password(email, password)
      Aikotoba::Account.new(email: email, password: password).tap do |resource|
        resource.strategy = :email_password
        password_digest = build_digest(resource.password)
        resource.assign_attributes(password_digest: password_digest)
      end
    end

    def build_digest(password)
      generate_hash(password_with_papper(password))
    end

    def password_with_papper(password)
      "#{password}-#{Aikotoba.password_papper}"
    end

    def generate_hash(password)
      argon = Argon2::Password.new(t_cost: Aikotoba.password_stretch)
      argon.create(password)
    end
  end
end
