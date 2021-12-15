# frozen_string_literal: true

module Aikotoba
  class Account::Strategy::EmailPassword < Account::Strategy::Base
    include BCrypt

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
      Password.new(account.password_digest) == password_with_papper(password)
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
      Password.create(password, cost: Aikotoba.password_stretch)
    end
  end
end
