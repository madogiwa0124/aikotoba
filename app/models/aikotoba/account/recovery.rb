# frozen_string_literal: true

module Aikotoba
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
      #       invalid new_password would be (RecordInvalid -> :password error) instead
      #       of raising NoMethodError on a nil association.
      unless @account.password
        @account.errors.add(:password, :blank)
        raise ActiveRecord::RecordInvalid, @account
      end

      ActiveRecord::Base.transaction do
        @account.password.recover!(new_password)
        @account.recovery_token&.destroy!
      end
    rescue ActiveRecord::RecordInvalid => e
      raise if e.record == @account
      e.record.errors.each { |error| @account.errors.import(error, attribute: :password) }
      raise ActiveRecord::RecordInvalid, @account
    end
  end
end
