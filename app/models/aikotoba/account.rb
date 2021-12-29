# frozen_string_literal: true

module Aikotoba
  class Account < ApplicationRecord
    class InvalidStrategy < StandardError; end
    STRATEGIES = {email_password: Strategy::EmailPassword}
    PASSWORD_MINIMUM_LENGTH = Aikotoba.password_minimum_length

    belongs_to :authenticate_target, polymorphic: true, optional: true

    attribute :password, :string
    validates :password, presence: true, on: :create
    validates :password, length: {minimum: PASSWORD_MINIMUM_LENGTH}, allow_blank: true, on: :create
    validates :password_digest, presence: true
    validates :email, presence: true, uniqueness: true

    enum strategy: STRATEGIES.keys

    scope :confirmable, -> { where(strategy: confirmable_strategies.keys) }
    scope :lockable, -> { where(strategy: lockable_strategies.keys) }
    scope :authenticatable, -> {
      result = all
      result = result.confirmed if enable_confirm?
      result = result.unlocked if enable_lock?
      result
    }

    after_initialize do
      if authenticate_target
        target_type_name = authenticate_target_type.gsub("::", "").underscore
        define_singleton_method(target_type_name) { authenticate_target }
      end
    end

    class << self
      def build_account_by(strategy:, attributes:)
        strategy = authenticate_strategy(strategy)
        strategy.build_account_by(attributes)
      end

      def find_account_by(strategy:, attributes:)
        strategy = authenticate_strategy(strategy)
        strategy.find_account_by(attributes)
      end

      def enable_lock?
        Aikotoba.enable_lock
      end

      def enable_confirm?
        Aikotoba.enable_confirm
      end

      def lockable_strategies
        STRATEGIES.select { |k, v| v.lockable? }
      end

      def confirmable_strategies
        STRATEGIES.select { |k, v| v.confirmable? }
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
        scope :confirmed, -> { where(confirmed: true) }
      end

      def update_confirm_token!
        update!(confirm_token: build_confirm_token)
      end

      def send_confirm_token
        AccountMailer.with(account: self).confirm.deliver_now
      end

      def confirm!
        update!(confirmed: true)
      end

      private

      def build_confirm_token
        SecureRandom.hex(32)
      end
    end

    concerning :Lockable do
      included do
        scope :locked, -> { where(locked: true) }
        scope :unlocked, -> { where(locked: false) }
      end

      def lock_when_exceed_max_failed_attempts!
        ActiveRecord::Base.transaction do
          increment!(:failed_attempts)
          lock! if failed_attempts > max_failed_attempts
        end
      end

      def lock!
        update!(locked: true, unlock_token: build_unlock_token)
      end

      def unlock!
        update!(locked: false, unlock_token: nil, failed_attempts: 0)
      end

      def send_unlock_token
        AccountMailer.with(account: self).unlock.deliver_now
      end

      private

      def max_failed_attempts
        Aikotoba.max_failed_attempts
      end

      def build_unlock_token
        SecureRandom.hex(32)
      end
    end
  end
end
