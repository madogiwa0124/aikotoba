# frozen_string_literal: true

module Aikotoba
  class Account::RecoveryToken < ApplicationRecord
    include TokenEncryptable

    belongs_to :account, class_name: "Aikotoba::Account", foreign_key: "aikotoba_account_id"
    validates :token, presence: true
    validates :expired_at, presence: true

    scope :active, ->(now: Time.current) { where("expired_at >= ?", now) }
    scope :for_target_type, ->(target_type_name) { joins(:account).merge(Account.for_target_type(target_type_name)) }

    after_initialize do |record|
      token = Account::Token.new(expiry: Aikotoba.recovery_token_expiry)
      record.token ||= token.value
      record.expired_at ||= token.expired_at
    end

    # NOTE: Waits for every open transaction (including callers' outer ones) to commit,
    #       and is dropped on rollback, so a sent link never points at a missing token.
    def notify
      ActiveRecord.after_all_transactions_commit do
        AccountMailer.with(account: account).recover.deliver_later
      end
    end
  end
end
