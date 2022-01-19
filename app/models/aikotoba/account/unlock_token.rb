# frozen_string_literal: true

module Aikotoba
  class Account::UnlockToken < ApplicationRecord
    belongs_to :account, class_name: "Aikotoba::Account", foreign_key: "aikotoba_account_id"
    validates :token, presence: true
    validates :expired_at, presence: true

    scope :active, ->(now: Time.current) { where("expired_at >= ?", now) }

    after_initialize do |token|
      token.token ||= SecureRandom.urlsafe_base64(32)
      token.expired_at ||= Aikotoba.unlock_token_expiry.since
    end

    def notify
      AccountMailer.with(account: account).unlock.deliver_now
    end
  end
end
