# frozen_string_literal: true

module Aikotoba
  class Account::Authentication
    def self.call!(email:, password:)
      new(email: email, password: password).call!
    end

    def initialize(email:, password:)
      @email = email
      @password = password
      @enable_lock = Account.enable_lock?
      @max_failed_attempts = Account.max_failed_attempts
    end

    def call!
      account = find_by_identifier
      result = authenticate(account)
      reset_or_lock!(success: result, account: account) if @enable_lock
      result
    end

    private

    def find_by_identifier
      Account.authenticatable.find_by(email: @email)
    end

    def authenticate(account)
      return unless account
      password_match?(account.password_digest) ? account : nil
    end

    def password_match?(password_digest)
      password = Account::Password.new(value: @password)
      password.match?(digest: password_digest)
    end

    concerning :Lockable do
      def reset_or_lock!(success:, account:)
        return unless account
        if success
          reset_lock_status!(account)
        else
          lock_when_exceed_max_failed_attempts!(account)
        end
      end

      private

      def reset_lock_status!(account)
        account.unlock! if account.failed_attempts.positive?
      end

      def lock_when_exceed_max_failed_attempts!(account)
        ActiveRecord::Base.transaction do
          account.increment!(:failed_attempts)
          account.lock! if account.failed_attempts > @max_failed_attempts
        end
      end
    end
  end
end
