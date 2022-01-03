# frozen_string_literal: true

module Aikotoba
  class Account::Registration
    def self.build(email:, password:)
      new.build(email: email, password: password)
    end

    def self.save_with_callbacks!(account:)
      new.save_with_callbacks!(account: account)
    end

    def initialize
      @enable_confirm = Account.enable_confirm?
    end

    def build(email:, password:)
      Account.new(email: email, password: password).tap do |resource|
        password_digest = build_password_digest(password)
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

    def build_password_digest(password)
      Account::Password.new(value: password).digest
    end

    concerning :Confirmable do
      def send_confirmation_token!(account)
        Account::Confirmation.create_token!(account: account, notify: true)
      end
    end
  end
end
