# frozen_string_literal: true

module Aikotoba
  class Account::Service::Recovery
    def self.create_token!(account:, notify: false)
      new(account: account).create_token!(notify: notify)
    end

    def self.recover!(account:, new_password:)
      new(account: account).recover!(new_password: new_password)
    end

    def initialize(account:)
      @account = account
      @password_class = Account::Password
    end

    def create_token!(notify:)
      ActiveRecord::Base.transaction do
        @account.build_recovery_token.save!
        @account.recovery_token.notify if notify
      end
    end

    def recover!(new_password:)
      ActiveRecord::Base.transaction do
        password = @password_class.new(value: new_password)
        @account.recover!(new_password: password.value, new_password_digest: password.digest)
        @account.recovery_token&.destroy!
      end
    end
  end
end
