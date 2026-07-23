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
      ActiveRecord::Base.transaction do
        @account.password.recover!(new_password)
        @account.recovery_token&.destroy!
      end
    rescue ActiveRecord::RecordInvalid => e
      e.record.errors.each { |error| @account.errors.import(error, attribute: :password) }
      raise ActiveRecord::RecordInvalid, @account
    end
  end
end
