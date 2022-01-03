# frozen_string_literal: true

module Aikotoba
  class Account::UnlockToken < ApplicationRecord
    belongs_to :account, class_name: "Aikotoba::Account", foreign_key: "aikotoba_account_id"
    validates :token, presence: true

    after_initialize do |token|
      token.token ||= SecureRandom.urlsafe_base64(32)
    end

    def notify
      AccountMailer.with(account: account).unlock.deliver_now
    end
  end
end
