# frozen_string_literal: true

module Aikotoba
  class Account::Lock
    def self.lock!(account:, notify: false)
      new(account: account).lock!(notify: notify)
    end

    def self.unlock!(account:)
      new(account: account).unlock!
    end

    def self.create_token!(account:, notify: false)
      new(account: account).create_token!(notify: notify)
    end

    def initialize(account:)
      @account = account
    end

    def lock!(notify:)
      ActiveRecord::Base.transaction do
        @account.lock!
        create_token!(notify: notify)
        Event::AccountLocked.report(account_id: @account.id)
      end
    end

    def unlock!
      ActiveRecord::Base.transaction do
        @account.unlock!
        @account.unlock_token&.destroy!
        Event::AccountUnlocked.report(account_id: @account.id)
      end
    end

    def create_token!(notify:)
      ActiveRecord::Base.transaction do
        @account.build_unlock_token.save!
        @account.unlock_token.notify if notify
        Event::UnlockTokenIssued.report(account_id: @account.id, notified: notify)
      end
    end
  end
end
