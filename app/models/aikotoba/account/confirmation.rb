# frozen_string_literal: true

module Aikotoba
  class Account::Confirmation
    def self.create_token!(account:, notify:)
      new(account: account).create_token!(notify: notify)
    end

    def self.confirm!(account:)
      new(account: account).confirm!
    end

    def initialize(account:)
      @account = account
    end

    def create_token!(notify: false)
      ActiveRecord::Base.transaction do
        @account.build_confirmation_token.save!
        @account.confirmation_token.notify if notify
      end
    end

    def confirm!
      ActiveRecord::Base.transaction do
        @account.update!(confirmed: true)
        @account.confirmation_token&.destroy!
      end
    end
  end
end
