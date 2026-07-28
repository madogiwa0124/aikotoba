# frozen_string_literal: true

module Aikotoba
  # NOTE: The web-facing shape here (token, controller, routes) is deliberately generic/
  #       Account-level, mirroring how SessionsController stays generic while delegating
  #       the actual credential check to Account::PasswordHash.authenticate_by -- a
  #       recovery token proves ownership of the account/email, which is an account-level
  #       concept, not a credential-specific one. But the *operation* this class performs
  #       is still hardcoded to password reset (`new_password:`, `@account.password_hash`)
  #       -- there's no polymorphism yet for recovering some other future credential type.
  #       If/when a second auth method needs its own recovery-like flow, revisit whether
  #       this should generalize or whether that method should own a separate mechanism.
  class Account::Recovery
    def self.create_token!(account:, notify: false)
      new(account: account).create_token!(notify: notify)
    end

    def self.recover!(account:, new_password:)
      new(account: account).recover!(new_password: new_password)
    end

    def initialize(account:)
      @account = account
    end

    def create_token!(notify:)
      ActiveRecord::Base.transaction do
        @account.build_recovery_token.save!
        @account.recovery_token.notify if notify
      end
    end

    def recover!(new_password:)
      # NOTE: An account can legitimately have no password (e.g. a magic-link-only
      #       account), so there's nothing to recover. Surface this the same way an
      #       invalid new_password would be (RecordInvalid -> :password_hash error)
      #       instead of raising NoMethodError on a nil association.
      unless @account.password_hash
        @account.errors.add(:password_hash, :blank)
        raise ActiveRecord::RecordInvalid, @account
      end

      ActiveRecord::Base.transaction do
        @account.password_hash.recover!(new_password)
        @account.recovery_token&.destroy!
      end
    rescue ActiveRecord::RecordInvalid => e
      raise if e.record == @account
      # NOTE: e.record here is @account.password_hash, not @account -- its own save!
      #       failed, so @account.errors is still empty. The controller re-renders using
      #       @account.errors, so copy the errors over (attribute: :password_hash also
      #       gives them a clean display label via config/locales/en.yml).
      e.record.errors.each { |error| @account.errors.import(error, attribute: :password_hash) }
      raise ActiveRecord::RecordInvalid, @account
    end
  end
end
