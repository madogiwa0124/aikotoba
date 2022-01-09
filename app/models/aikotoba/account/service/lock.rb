# frozen_string_literal: true

module Aikotoba
  class Account::Service::Lock
    def self.lock!(account:, notify: false)
      new(account: account).lock!(notify: notify)
    end

    def self.unlock!(account:)
      new(account: account).unlock!
    end

    def initialize(account:)
      @account = account
    end

    def lock!(notify:)
      ActiveRecord::Base.transaction do
        @account.lock!
        @account.build_unlock_token.save!
        @account.unlock_token.notify if notify
      end
    end

    def unlock!
      ActiveRecord::Base.transaction do
        @account.unlock!
        @account.unlock_token&.destroy!
      end
    end
  end
end
