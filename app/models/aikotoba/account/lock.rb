# frozen_string_literal: true

module Aikotoba
  class Account::Lock
    def self.lock!(account:, notify:)
      new(account: account).lock!(notify: notify)
    end

    def self.unlock!(account:)
      new(account: account).unlock!
    end

    def initialize(account:)
      @account = account
    end

    def lock!(notify: false)
      ActiveRecord::Base.transaction do
        @account.update!(locked: true)
        @account.build_unlock_token.save!
        @account.unlock_token.notify if notify
      end
    end

    def unlock!
      ActiveRecord::Base.transaction do
        @account.update!(locked: false, failed_attempts: 0)
        @account.unlock_token&.destroy!
      end
    end
  end
end
