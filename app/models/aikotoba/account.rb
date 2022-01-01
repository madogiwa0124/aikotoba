# frozen_string_literal: true

module Aikotoba
  class Account < ApplicationRecord
    PASSWORD_MINIMUM_LENGTH = Aikotoba.password_minimum_length
    EMAIL_REGEXP = /\A[^\s]+@[^\s]+\z/

    belongs_to :authenticate_target, polymorphic: true, optional: true

    attribute :password, :string
    validates :email, presence: true, uniqueness: true, format: EMAIL_REGEXP
    validates :password, presence: true, on: :create
    validates :password, length: {minimum: PASSWORD_MINIMUM_LENGTH}, allow_blank: true, on: :create
    validates :password_digest, presence: true
    validates :confirmed, inclusion: [true, false]
    validates :failed_attempts, presence: true, numericality: true
    validates :locked, inclusion: [true, false]

    after_initialize do
      if authenticate_target
        target_type_name = authenticate_target_type.gsub("::", "").underscore
        define_singleton_method(target_type_name) { authenticate_target }
      end
    end

    class << self
      def enable_lock?
        Aikotoba.enable_lock
      end

      def enable_confirm?
        Aikotoba.enable_confirm
      end

      def enable_recover?
        Aikotoba.enable_recover
      end
    end

    concerning :Registrable do
      class_methods do
        def build_account_by(attributes:)
          email, password = attributes.values_at(:email, :password)
          new(email: email, password: password).tap do |resource|
            password_digest = Password.new(value: resource.password).digest
            resource.assign_attributes(password_digest: password_digest)
          end
        end
      end
    end

    concerning :Authenticatable do
      included do
        scope :authenticatable, -> {
          result = all
          result = result.confirmed if enable_confirm?
          result = result.unlocked if enable_lock?
          result
        }
      end

      class_methods do
        def find_account_by(attributes:)
          email, password = attributes.values_at(:email, :password)
          account = authenticatable.find_by(email: email)
          password = Password.new(value: password)
          account if account && password.match?(digest: account.password_digest)
        end
      end
    end

    concerning :Confirmable do
      included do
        scope :confirmed, -> { where(confirmed: true) }
        scope :unconfirmed, -> { where(confirmed: false) }
      end

      def update_confirm_token!
        update!(confirm_token: build_confirm_token)
      end

      def send_confirm_token
        AccountMailer.with(account: self).confirm.deliver_now
      end

      def confirm!
        update!(confirmed: true, confirm_token: nil)
      end

      private

      def build_confirm_token
        SecureRandom.urlsafe_base64(32)
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
        SecureRandom.urlsafe_base64(32)
      end
    end

    concerning :Recoverable do
      def recover!(password:)
        password = Password.new(value: password)
        assign_attributes(password: password.value, password_digest: password.digest, recover_token: nil)
        # NOTE: To verify the password, run the verification in the same context as when it was created.
        save!(context: :create)
      end

      def update_recover_token!
        update!(recover_token: build_recover_token)
      end

      def send_recover_token
        AccountMailer.with(account: self).recover.deliver_now
      end

      private

      def build_recover_token
        SecureRandom.urlsafe_base64(32)
      end
    end
  end
end
