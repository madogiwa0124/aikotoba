# frozen_string_literal: true

module Aikotoba
  class Account::Registration
    def self.build(email:, password:)
      new(email: email, password: password).build
    end

    def initialize(email:, password:)
      @email = email
      @password = password
    end

    def build
      Account.new(email: @email, password: @password).tap do |resource|
        password_digest = build_password_digest(@password)
        resource.assign_attributes(password_digest: password_digest)
      end
    end

    private

    def build_password_digest(password)
      Account::Password.new(value: password).digest
    end
  end
end
