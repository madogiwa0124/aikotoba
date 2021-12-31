# frozen_string_literal: true

require "argon2"

module Aikotoba
  class Account::Password
    def initialize(
      value:,
      stretch: Aikotoba.password_stretch,
      pepper: Aikotoba.password_pepper
    )
      @value = value
      @stretch = stretch
      @pepper = pepper
    end

    attr_reader :value

    def match?(digest:)
      verify_password?(password_with_pepper(value), digest)
    end

    def digest
      generate_hash(password_with_pepper(value))
    end

    private

    def verify_password?(password, digest)
      Argon2::Password.verify_password(password, digest)
    end

    def password_with_pepper(password)
      "#{password}-#{@pepper}"
    end

    def generate_hash(password)
      argon = Argon2::Password.new(t_cost: @stretch)
      argon.create(password)
    end
  end
end
