# frozen_string_literal: true

module Aikotoba
  class Account::UnlockToken < ApplicationRecord
    include TokenEncryptable

    belongs_to :account, class_name: "Aikotoba::Account", foreign_key: "aikotoba_account_id"
    validates :token, presence: true
    validates :expired_at, presence: true

    scope :active, ->(now: Time.current) { where("expired_at >= ?", now) }

    after_initialize do |record|
      token = Account::Token.new(expiry: Aikotoba.unlock_token_expiry)
      record.token ||= token.value
      record.expired_at ||= token.expired_at
    end

    def notify
      AccountMailer.with(account: account).unlock.deliver_now
    end
  end
end
