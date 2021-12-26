# frozen_string_literal: true

module Aikotoba
  class Account < ApplicationRecord
    class InvalidStrategy < StandardError; end
    STRATEGIES = {password_only: Strategy::PasswordOnly, email_password: Strategy::EmailPassword}

    belongs_to :authenticate_target, polymorphic: true, optional: true
    validates :password_digest, presence: true
    validates :email, presence: true, uniqueness: true, if: :email_password?

    enum strategy: {password_only: 0, email_password: 1}

    scope :authenticatable, -> { enable_confirm? ? confirmed : all }

    attribute :password, :string

    after_initialize do
      if authenticate_target
        target_type_name = authenticate_target_type.gsub("::", "").underscore
        define_singleton_method(target_type_name) { authenticate_target }
      end
    end

    class << self
      def build_account_by(attributes)
        strategy = authenticate_strategy(attributes["strategy"])
        strategy.build_account_by(attributes)
      end

      def find_account_by(credentials)
        strategy = authenticate_strategy(credentials["strategy"])
        strategy.find_account_by(credentials)
      end

      private

      def authenticate_strategy(strategy)
        target = STRATEGIES[strategy.to_sym]
        raise InvalidStrategy unless target
        target
      end
    end

    concerning :Confirmable do
      included do
        scope :confirmable, -> { where(strategy: confirmable_strategys.keys) }
        scope :confirmed, -> { where(confirmed: true) }
      end

      class_methods do
        def enable_confirm?
          Aikotoba.enable_confirm
        end

        def confirmable_strategys
          Aikotoba::Account::STRATEGIES.select { |k, v| v.confirmable? }
        end
      end

      def send_confirm_token!
        update!(confirm_token: build_confirm_token)
        AccountMailer.with(account: self).confirm.deliver_now
      end

      private

      def build_confirm_token
        SecureRandom.hex(32)
      end
    end
  end
end
