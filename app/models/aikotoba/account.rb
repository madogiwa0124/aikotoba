# frozen_string_literal: true

module Aikotoba
  class Account < ApplicationRecord
    PASSWORD_MINIMUM_LENGTH = Aikotoba.password_minimum_length
    EMAIL_REGEXP = /\A[^\s]+@[^\s]+\z/

    belongs_to :authenticate_target, polymorphic: true, optional: true

    attribute :password, :string
    validates :email, presence: true, uniqueness: true, format: EMAIL_REGEXP
    validates :password, presence: true, on: [:create, :recover]
    validates :password, length: {minimum: PASSWORD_MINIMUM_LENGTH}, allow_blank: true, on: [:create, :recover]
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
        def build_by(attributes:)
          email, password = attributes.values_at(:email, :password)
          Registration.build(email: email, password: password)
        end
      end

      def save_with_callbacks!
        Registration.save_with_callbacks!(account: self)
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
        def authenticate_by(attributes:)
          email, password = attributes.values_at(:email, :password)
          Authentication.call!(email: email, password: password)
        end
      end

      def authentication_failed!
        increment!(:failed_attempts)
      end

      def authentication_success!
        update!(failed_attempts: 0)
      end
    end

    concerning :Confirmable do
      included do
        has_one :confirmation_token, dependent: :destroy, foreign_key: "aikotoba_account_id"
        scope :confirmed, -> { where(confirmed: true) }
        scope :unconfirmed, -> { where(confirmed: false) }
      end

      def confirm!
        update!(confirmed: true)
      end
    end

    concerning :Lockable do
      included do
        has_one :unlock_token, dependent: :destroy, foreign_key: "aikotoba_account_id"
        scope :locked, -> { where(locked: true) }
        scope :unlocked, -> { where(locked: false) }
      end

      class_methods do
        def max_failed_attempts
          Aikotoba.max_failed_attempts
        end
      end

      def should_lock?
        failed_attempts > Account.max_failed_attempts
      end

      def lock!
        update!(locked: true)
      end

      def unlock!
        update!(locked: false, failed_attempts: 0)
      end
    end

    concerning :Recoverable do
      included do
        has_one :recovery_token, dependent: :destroy, foreign_key: "aikotoba_account_id"
      end

      def recover!(new_password:, new_password_digest:)
        assign_attributes(password: new_password, password_digest: new_password_digest)
        save!(context: :recover)
      end
    end
  end
end
