# frozen_string_literal: true

module Aikotoba
  class Account::ConfirmationToken < ApplicationRecord
    include TokenEncryptable
    belongs_to :account, class_name: "Aikotoba::Account", foreign_key: "aikotoba_account_id"
    validates :token, presence: true
    validates :expired_at, presence: true

    scope :active, ->(now: Time.current) { where("expired_at >= ?", now) }

    after_initialize do |record|
      token = Account::Token.new(extipry: Aikotoba.confirmation_token_expiry)
      record.token ||= token.value
      record.expired_at ||= token.expired_at
    end

    def notify
      AccountMailer.with(account: account).confirm.deliver_now
    end
  end
end
