# frozen_string_literal: true

require "argon2"

module Aikotoba
  class Account::Password::Argon2
    def initialize(password:)
      @password = password
    end

    def verify_password?(digest)
      Argon2::Password.verify_password(@password, digest)
    rescue Argon2::ArgonHashFail # NOTE: If an invalid digest is passed, consider it a mismatch.
      false
    end

    def generate_hash
      # NOTE: Adjusted to be OWASAP's recommended value by default.
      # > Use Argon2id with a minimum configuration of 15 MiB of memory, an iteration count of 2, and 1 degree of parallelism.
      # > https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html#introduction
      argon = Argon2::Password.new(t_cost: 2, m_cost: 14, p_cost: 1)
      argon.create(@password)
    end
  end
end
