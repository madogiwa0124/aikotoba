# frozen_string_literal: true

require "argon2"

module Aikotoba
  class Account::Password
    FORMAT = Aikotoba.password_format
    INVALID_FORMAT_MESSAGE = I18n.t(".aikotoba.messages.registration.invalid_password")

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
      # NOTE: Adjusted to be OWASAP's recommended value by default.
      # > Use Argon2id with a minimum configuration of 15 MiB of memory, an iteration count of 2, and 1 degree of parallelism.
      # > https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html#introduction
      argon = Argon2::Password.new(t_cost: @stretch, m_cost: 14, p_cost: 1)
      argon.create(password)
    end
  end
end
