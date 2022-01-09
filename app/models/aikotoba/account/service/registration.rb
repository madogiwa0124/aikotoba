# frozen_string_literal: true

module Aikotoba
  class Account::Service::Registration
    def self.build(email:, password:)
      new.build(email: email, password: password)
    end

    def self.save_with_callbacks!(account:)
      new.save_with_callbacks!(account: account)
    end

    def initialize
      @password_class = Account::Password
      @account_class = Account
      @confirm_service = Account::Service::Confirmation
      @enable_confirm = @account_class.enable_confirm?
    end

    def build(email:, password:)
      @account_class.new(email: email, password: password).tap do |resource|
        password_digest = @password_class.new(value: password).digest
        resource.assign_attributes(password_digest: password_digest)
      end
    end

    def save_with_callbacks!(account:)
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
