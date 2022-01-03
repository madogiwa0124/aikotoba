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
          Authentication.call(email: email, password: password)
        end
      end
    end

    concerning :Confirmable do
      included do
        has_one :confirmation_token, dependent: :destroy, foreign_key: "aikotoba_account_id"

        scope :confirmed, -> { where(confirmed: true) }
        scope :unconfirmed, -> { where(confirmed: false) }
      end

      def confirm!
        ActiveRecord::Base.transaction do
          update!(confirmed: true)
          confirmation_token&.destroy!
        end
      end

      def send_confirmation_token!
        build_confirmation_token.save!
        confirmation_token.notify
      end
    end

    concerning :Lockable do
      included do
        has_one :unlock_token, dependent: :destroy, foreign_key: "aikotoba_account_id"

        scope :locked, -> { where(locked: true) }
        scope :unlocked, -> { where(locked: false) }
      end

      def lock_when_exceed_max_failed_attempts!
        ActiveRecord::Base.transaction do
          increment!(:failed_attempts)
          if failed_attempts > max_failed_attempts
            lock!
            unlock_token.notify
          end
        end
      end

      def reset_lock_status!
        unlock! if failed_attempts.positive?
      end

      def lock!
        ActiveRecord::Base.transaction do
          update!(locked: true)
          build_unlock_token.save!
        end
      end

      def unlock!
        ActiveRecord::Base.transaction do
          update!(locked: false, failed_attempts: 0)
          unlock_token&.destroy!
        end
      end

      private

      def max_failed_attempts
        Aikotoba.max_failed_attempts
      end
    end

    concerning :Recoverable do
      included do
        has_one :recovery_token, dependent: :destroy, foreign_key: "aikotoba_account_id"
      end

      def recover!(password:)
        ActiveRecord::Base.transaction do
          password = Password.new(value: password)
          assign_attributes(password: password.value, password_digest: password.digest)
          save!(context: :recover)
          recovery_token&.destroy!
        end
      end

      def send_recovery_token!
        build_recovery_token.save!
        recovery_token.notify
      end
    end
  end
end
