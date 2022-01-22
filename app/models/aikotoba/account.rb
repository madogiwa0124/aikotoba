# frozen_string_literal: true

module Aikotoba
  class Account < ApplicationRecord
    include EnabledFeatureCheckable
    # NOTE: (RFC5321) Path: The maximum total length of a reverse-path or forward-path is 256 octets.
    # https://datatracker.ietf.org/doc/html/rfc5321#section-4.5.3.1.3
    EMAIL_MAXIMUM_LENGTH = 256
    EMAIL_REGEXP = Aikotoba.email_format

    belongs_to :authenticate_target, polymorphic: true, optional: true

    attribute :password, :string
    attribute :max_failed_attempts, :integer, default: -> { Aikotoba.max_failed_attempts }

    validates :email, presence: true, uniqueness: true, format: EMAIL_REGEXP, length: {maximum: EMAIL_MAXIMUM_LENGTH}
    validates :password, presence: true, format: {with: Password::FORMAT, message: Password::INVALID_FORMAT_MESSAGE}, on: [:create, :recover]
    validates :password_digest, presence: true
    validates :confirmed, inclusion: [true, false]
    validates :failed_attempts, presence: true, numericality: {only_integer: true, greater_than_or_equal_to: 0}
    validates :max_failed_attempts, numericality: {only_integer: true, greater_than: 0}
    validates :locked, inclusion: [true, false]

    after_initialize do
      if authenticate_target
        target_type_name = authenticate_target_type.gsub("::", "").underscore
        define_singleton_method(target_type_name) { authenticate_target }
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
          Service::Authentication.call!(email: email, password: password)
        end
      end

      def password_match?(password)
        Password.new(value: password).match?(digest: password_digest)
      end

      def authentication_failed!
        increment!(:failed_attempts)
      end

      def authentication_success!
        update!(failed_attempts: 0)
      end
    end

    concerning :Registrable do
      class_methods do
        def build_by(attributes:)
          email, password = attributes.values_at(:email, :password)
          new(email: email, password: password)
        end
      end

      def password=(value)
        new_password = Password.new(value: value)
        write_attribute(:password, new_password.value)
        write_attribute(:password_digest, new_password.digest)
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

      def should_lock?
        failed_attempts > max_failed_attempts
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

      def recover!(new_password:)
        assign_attributes(password: new_password)
        save!(context: :recover)
      end
    end
  end
end
