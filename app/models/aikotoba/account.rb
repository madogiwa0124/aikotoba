# frozen_string_literal: true

module Aikotoba
  class Account < ApplicationRecord
    include EnabledFeatureCheckable

    # NOTE: (RFC5321) Path: The maximum total length of a reverse-path or forward-path is 256 octets.
    # https://datatracker.ietf.org/doc/html/rfc5321#section-4.5.3.1.3
    EMAIL_MAXIMUM_LENGTH = 256
    EMAIL_REGEXP = Aikotoba.email_format

    belongs_to :authenticate_target, polymorphic: true, optional: true

    attribute :max_failed_attempts, :integer, default: -> { Aikotoba.max_failed_attempts }

    validates :email, presence: true, uniqueness: {case_sensitive: false}, format: EMAIL_REGEXP, length: {maximum: EMAIL_MAXIMUM_LENGTH}
    validates :password, presence: true, length: {in: Password::LENGTH_RENGE}, on: [:create, :recover]
    validates :password_digest, presence: true
    validates :confirmed, inclusion: [true, false]
    validates :failed_attempts, presence: true, numericality: {only_integer: true, greater_than_or_equal_to: 0}
    validates :max_failed_attempts, numericality: {only_integer: true, greater_than: 0}
    validates :locked, inclusion: [true, false]

    # NOTE: (RFC5321) Per the RFC, the local part of an email address is case-sensitive,
    #       but in practice it is usually ignored, so we normalize to lowercase.
    # > exploiting the case sensitivity of mailbox local-parts impedes interoperability and
    # > is discouraged.  Mailbox domains follow normal DNS rules and are hence not case sensitive
    # > https://datatracker.ietf.org/doc/html/rfc5321#section-2.4
    normalizes :email, with: ->(value) { value.strip.downcase }

    after_initialize do
      if authenticate_target
        target_type_name = authenticate_target_type.gsub("::", "").underscore
        define_singleton_method(target_type_name) { authenticate_target }
      end
    end

    attr_reader :password

    def password=(value)
      new_password = Password.new(value: value)
      @password = new_password.value
      assign_attributes(password_digest: new_password.digest)
    end

    concerning :Authenticatable do
      included do
        has_many :sessions,
          class_name: "Aikotoba::Account::Session",
          dependent: :destroy,
          foreign_key: "aikotoba_account_id"

        scope :authenticatable, ->(target_type_name: nil) {
          result = all
          # NOTE: To ensure that authentication works even if a Class is passed to authenticate_for,
          #       convert it to a string for searching.
          result = result.where(authenticate_target_type: target_type_name.to_s) if target_type_name.present?
          result = result.confirmed if confirmable?
          result = result.unlocked if lockable?
          result
        }
      end

      class_methods do
        def authenticate_by(attributes:, target_type_name: nil)
          email, password = attributes.values_at(:email, :password)
          account = find_by_identifier(email, target_type_name: target_type_name)
          return prevent_timing_atack(email, password) unless account

          account.authenticate(password).tap do |result|
            ActiveRecord::Base.transaction do
              if result
                account.authentication_success!
              else
                account.authentication_failed!
                Lock.lock!(account: account, notify: true) if lockable? && account.should_lock?
              end
            end
          end
        end

        private

        def find_by_identifier(email, target_type_name: nil)
          authenticatable(target_type_name: target_type_name).find_by(email: email)
        end

        # NOTE: Verify passwords even when accounts are not found to prevent timing attacks.
        def prevent_timing_atack(email, password)
          account = build_by(attributes: {email: email, password: password})
          account.password_match?(password)
          nil
        end
      end

      def authenticate(input_password)
        password_match?(input_password) ? self : nil
      end

      def authentication_failed!
        increment!(:failed_attempts)
      end

      def authentication_success!
        update!(failed_attempts: 0)
      end

      def password_match?(input_password)
        Password.new(value: input_password).match?(digest: password_digest)
      end
    end

    concerning :Registrable do
      class_methods do
        def build_by(attributes:)
          email, password = attributes.values_at(:email, :password)
          new(email: email).tap { |account| account.password = password }
        end
      end

      def register!
        ActiveRecord::Base.transaction do
          save!
          Confirmation.create_token!(account: self, notify: true) if confirmable?
        end
      end
    end

    concerning :Confirmable do
      included do
        has_one :confirmation_token,
          dependent: :destroy,
          foreign_key: "aikotoba_account_id"
        scope :confirmed, -> { where(confirmed: true) }
        scope :unconfirmed, -> { where(confirmed: false) }
      end

      def confirm!
        update!(confirmed: true)
      end
    end

    concerning :Lockable do
      included do
        has_one :unlock_token,
          dependent: :destroy,
          foreign_key: "aikotoba_account_id"
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
        has_one :recovery_token,
          dependent: :destroy,
          foreign_key: "aikotoba_account_id"
      end

      def recover!(new_password:)
        self.password = new_password
        save!(context: :recover)
      end
    end
  end
end
