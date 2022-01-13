# frozen_string_literal: true

module Aikotoba
  class Account::Service::Registration
    def self.call!(account:)
      new.call!(account: account)
    end

    def initialize
      @account_class = Account
      @confirm_service = Account::Service::Confirmation
      @enable_confirm = @account_class.enable_confirm?
    end

    def call!(account:)
      ActiveRecord::Base.transaction do
        account.save!
        send_confirmation_token!(account) if @enable_confirm
      end
    end

    private

    concerning :Confirmable do
      def send_confirmation_token!(account)
        @confirm_service.create_token!(account: account, notify: true)
      end
    end
  end
end
