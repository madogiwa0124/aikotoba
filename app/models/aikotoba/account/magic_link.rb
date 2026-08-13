# frozen_string_literal: true

module Aikotoba
  class Account::MagicLink
    def self.create_token!(account:, notify: false)
      new(account: account).create_token!(notify: notify)
    end

    def self.authenticate_by(token:, target_type_name: nil)
      account = Account.authenticatable(target_type_name: target_type_name)
        .joins(:magic_link_token)
        .merge(Account::MagicLinkToken.active.where(token: token))
        .first
      return unless account

      new(account: account).authenticate!
    end

    def initialize(account:)
      @account = account
    end

    def create_token!(notify:)
      ActiveRecord::Base.transaction do
        @account.build_magic_link_token.save!
        @account.magic_link_token.notify if notify
      end
    end

    def authenticate!
      ActiveRecord::Base.transaction do
        @account.authentication_success!
        @account.magic_link_token.destroy!
      end
      @account
    end
  end
end
