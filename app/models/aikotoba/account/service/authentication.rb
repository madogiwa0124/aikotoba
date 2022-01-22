# frozen_string_literal: true

module Aikotoba
  class Account::Service::Authentication
    def self.call!(email:, password:)
      new(email: email, password: password).call!
    end

    def initialize(email:, password:)
      @account_class = Account
      @lock_service = Account::Service::Lock
      @lockable = @account_class.lockable?
      @email = email
      @password = password
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
      lock_when_should_lock!(account) if @lockable
    end

    def find_by_identifier
      @account_class.authenticatable.find_by(email: @email)
    end

    def authenticate(account)
      account.password_match?(@password) ? account : nil
    end

    concerning :Lockable do
      def lock_when_should_lock!(account)
        @lock_service.lock!(account: account, notify: true) if account.should_lock?
      end
    end
  end
end
