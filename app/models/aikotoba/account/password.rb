# frozen_string_literal: true

module Aikotoba
  class Account::Password < ApplicationRecord
    self.table_name = "aikotoba_account_passwords"

    LENGTH_RANGE = Aikotoba.password_length_range

    belongs_to :account, class_name: "Aikotoba::Account", foreign_key: "aikotoba_account_id", inverse_of: :password_credential

    validates :digest, presence: true

    attr_reader :value

    def value=(input, pepper: Aikotoba.password_pepper, algorithm_class: Argon2)
      @value = input
      self.digest = input.blank? ? "" : algorithm_class.new(password: with_pepper(input, pepper)).generate_hash
    end

    def match?(input, pepper: Aikotoba.password_pepper, algorithm_class: Argon2)
      algorithm_class.new(password: with_pepper(input, pepper)).verify_password?(digest)
    end

    private

    def with_pepper(input, pepper)
      "#{input}-#{pepper}"
    end
  end
end
