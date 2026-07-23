# frozen_string_literal: true

module Aikotoba
  class Account::Password < ApplicationRecord
    self.table_name = "aikotoba_account_passwords"

    LENGTH_RANGE = Aikotoba.password_length_range

    belongs_to :account, class_name: "Aikotoba::Account", foreign_key: "aikotoba_account_id", inverse_of: :password

    validates :digest, presence: true
    validates :value, presence: true, length: {in: LENGTH_RANGE}, on: [:create, :recover]

    attr_reader :value

    def value=(input, pepper: Aikotoba.password_pepper, algorithm_class: Argon2)
      @value = input
      self.digest = input.blank? ? "" : algorithm_class.new(password: with_pepper(input, pepper)).generate_hash
    end

    def match?(input, pepper: Aikotoba.password_pepper, algorithm_class: Argon2)
      algorithm_class.new(password: with_pepper(input, pepper)).verify_password?(digest)
    end

    def recover!(new_value)
      self.value = new_value
      save!(context: :recover)
    end

    class << self
      def authenticate_by(attributes:, target_type_name: nil)
        email, password = attributes.values_at(:email, :password)
        account = Account.find_by_identifier(email, target_type_name: target_type_name)
        return prevent_timing_attack(email: email, password: password) unless account

        matched = account.password&.match?(password) || false
        ActiveRecord::Base.transaction do
          if matched
            account.authentication_success!
          else
            account.authentication_failed!
            Account::Lock.lock!(account: account, notify: true) if account.lockable? && account.should_lock?
          end
        end
        matched ? account : nil
      end

      private

      # NOTE: Verify passwords even when accounts are not found to prevent timing attacks.
      def prevent_timing_attack(email:, password:)
        account = Account.build_by(attributes: {email: email, password: password})
        account.password&.match?(password)
        nil
      end
    end

    private

    def with_pepper(input, pepper)
      "#{input}-#{pepper}"
    end
  end
end
