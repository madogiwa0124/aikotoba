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
        def find_by_identifier(email, target_type_name: nil)
          authenticatable(target_type_name: target_type_name).find_by(email: email)
        end
      end

      def authentication_failed!
        increment!(:failed_attempts)
      end

      def authentication_success!
        update!(failed_attempts: 0)
      end
    end

    concerning :PasswordAuthenticatable do
      included do
        has_one :password_hash,
          class_name: "Aikotoba::Account::PasswordHash",
          dependent: :destroy,
          foreign_key: "aikotoba_account_id",
          autosave: true,
          inverse_of: :account
      end
    end

    concerning :Registrable do
      class_methods do
        # NOTE: This is one of the two places (see #update_by below) Account is allowed
        #       to know :password is a valid registration attribute (unlike the removed
        #       password/password=/password_digest delegators, which made Account speak
        #       password as its own API). It exists so callers can keep submitting a flat
        #       account[password] param instead of Rails' nested_attributes shape.
        #       Extracting a Registration class wouldn't remove this knowledge, only
        #       relocate it, so this is left as the accepted minimal seam.
        def build_by(attributes:)
          attrs = attributes.to_h.symbolize_keys
          has_password = attrs.key?(:password)
          password = attrs.delete(:password)
          new(attrs).tap { |account| account.build_password_hash.generate(password) if has_password }
        end

        def create_by!(attributes:)
          build_by(attributes: attributes).tap(&:save!)
        end
      end

      # NOTE: The update-side counterpart to .build_by -- without it, updating an
      #       existing account's password (e.g. alongside other attribute changes, in one
      #       validated save) requires knowing password_hash is the association name and
      #       that generate/build_password_hash is how to write to it. `account.update!
      #       (password: ...)` can't work here the same way `Account.new(password: ...)`
      #       can't: Account has no password= for mass-assignment to land on.
      def update_by(attributes:)
        attrs = attributes.to_h.symbolize_keys
        has_password = attrs.key?(:password)
        password = attrs.delete(:password)
        assign_attributes(attrs)
        (password_hash || build_password_hash).generate(password) if has_password
        self
      end

      def update_by!(attributes:)
        update_by(attributes: attributes).tap(&:save!)
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
    end
  end
end
