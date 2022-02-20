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
      return prevent_timing_atack && nil unless account

      authenticate(account).tap do |result|
        ActiveRecord::Base.transaction do
          result ? success_callback(account) : failed_callback(account)
        end
      end
    end

    private

    # NOTE: Verify passwords even when accounts are not found to prevent timing attacks.
    def prevent_timing_atack
      return true unless aikotoba_prevent_timing_atack
      account = @account_class.build_by(attributes: {email: @email, password: @password})
      account.password_match?(@password)
      true
    end

    def aikotoba_prevent_timing_atack
      Aikotoba.prevent_timing_atack
    end

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
