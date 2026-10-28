# frozen_string_literal: true

module Aikotoba
  class Account::Confirmation
    def self.create_token!(account:, notify: false)
      new(account: account).create_token!(notify: notify)
    end

    def self.confirm!(account:)
      new(account: account).confirm!
    end

    def initialize(account:)
      @account = account
    end

    def create_token!(notify:)
      ActiveRecord::Base.transaction do
        @account.build_confirmation_token.save!
        if notify
          @account.confirmation_token.notify
          Events.report_after_commit(:confirmation_token_sent, account_id: @account.id)
        end
      end
    end

    def confirm!
      ActiveRecord::Base.transaction do
        @account.confirm!
        @account.confirmation_token&.destroy!
        Events.report_after_commit(:account_confirmed, account_id: @account.id)
      end
    end
  end
end
