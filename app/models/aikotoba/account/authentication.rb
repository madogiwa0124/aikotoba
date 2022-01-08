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
    end

    def call!
      account = find_by_identifier
      return unless account
      authenticate(account).tap do |result|
        ActiveRecord::Base.transaction do
          result ? success_callback(account) : failed_callback(account)
        end
      end
    end

    private

    def success_callback(account)
      account.authentication_success!
    end

    def failed_callback(account)
      account.authentication_failed!
      lock_when_should_lock!(account) if @enable_lock
    end

    def find_by_identifier
      Account.authenticatable.find_by(email: @email)
    end

    def authenticate(account)
      password_match?(account.password_digest) ? account : nil
    end

    def password_match?(password_digest)
      password = Account::Password.new(value: @password)
      password.match?(digest: password_digest)
    end

    concerning :Lockable do
      def lock_when_should_lock!(account)
        Account::Lock.lock!(account: account, notify: true) if account.should_lock?
      end
    end
  end
end
