# frozen_string_literal: true

module Aikotoba
  class Account::Recovery
    def self.create_token!(account:, notify:)
      new(account: account).create_token!(notify: notify)
    end

    def self.recover!(account:, new_password:)
      new(account: account).recover!(new_password: new_password)
    end

    def initialize(account:)
      @account = account
    end

    def create_token!(notify: false)
      ActiveRecord::Base.transaction do
        @account.build_recovery_token.save!
        @account.recovery_token.notify if notify
      end
    end

    def recover!(new_password:)
      ActiveRecord::Base.transaction do
        password = Account::Password.new(value: new_password)
        @account.assign_attributes(password: password.value, password_digest: password.digest)
        @account.save!(context: :recover)
        @account.recovery_token&.destroy!
      end
    end
  end
end
