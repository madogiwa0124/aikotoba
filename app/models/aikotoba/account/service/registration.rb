# frozen_string_literal: true

module Aikotoba
  class Account::Service::Registration
    def self.call!(account:)
      new.call!(account: account)
    end

    def initialize
      @account_class = Account
      @confirm_service = Account::Service::Confirmation
      @confirmable = @account_class.confirmable?
    end

    def call!(account:)
      ActiveRecord::Base.transaction do
        account.save!
        send_confirmation_token!(account) if @confirmable
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
