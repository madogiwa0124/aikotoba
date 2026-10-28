# frozen_string_literal: true

module Aikotoba
  class Account::Lock
    def self.lock!(account:, notify: false)
      new(account: account).lock!(notify: notify)
    end

    def self.unlock!(account:)
      new(account: account).unlock!
    end

    def self.create_unlock_token!(account:, notify: false)
      new(account: account).create_unlock_token!(notify: notify)
    end

    def initialize(account:)
      @account = account
    end

    def lock!(notify:)
      ActiveRecord::Base.transaction do
        @account.lock!
        create_unlock_token!(notify: notify)
        Events.report_after_commit(:account_locked, account_id: @account.id)
      end
    end

    def unlock!
      ActiveRecord::Base.transaction do
        @account.unlock!
        @account.unlock_token&.destroy!
        Events.report_after_commit(:account_unlocked, account_id: @account.id)
      end
    end

    def create_unlock_token!(notify:)
      ActiveRecord::Base.transaction do
        @account.build_unlock_token.save!
        if notify
          @account.unlock_token.notify
          Events.report_after_commit(:unlock_token_sent, account_id: @account.id)
        end
      end
    end
  end
end
