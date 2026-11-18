# frozen_string_literal: true

module Aikotoba
  class Account::TwoFactor::EmailOtpCode < ApplicationRecord
    LENGTH = 6

    # NOTE: Set explicitly: nested under Account::TwoFactor, which isn't a model, Rails would
    #       infer "email_otp_codes", without the "aikotoba_account_" a class nested directly
    #       under Account gets. The table keeps the name the other optional tables follow.
    self.table_name = "aikotoba_account_email_otp_codes"

    # NOTE: Not TokenEncryptable, which encrypts a `token` column. Non-deterministic, since the
    #       code is never looked up by value: it is read through the account and compared.
    encrypts :code if Aikotoba.encrypted_token

    belongs_to :account, class_name: "Aikotoba::Account", foreign_key: "aikotoba_account_id"
    validates :code, presence: true
    validates :expired_at, presence: true
    validates :failed_attempts, numericality: {only_integer: true, greater_than_or_equal_to: 0}

    after_initialize do |record|
      record.code ||= self.class.generate_code
      record.expired_at ||= Aikotoba.email_otp_code_expiry.since
    end

    def self.generate_code
      SecureRandom.random_number(10**LENGTH).to_s.rjust(LENGTH, "0")
    end

    # NOTE: Usable while unexpired and below the attempt limit. A code used up by failed
    #       attempts is destroyed (see EmailOtp), so the limit check only guards a limit
    #       lowered while a code was outstanding.
    def active?(now: Time.current)
      expired_at >= now && failed_attempts < Aikotoba.email_otp_max_failed_attempts
    end

    def match?(input)
      ActiveSupport::SecurityUtils.secure_compare(code, input.to_s.gsub(/\s/, ""))
    end

    # NOTE: Waits for every open transaction (including callers' outer ones) to commit,
    #       and is dropped on rollback, so a sent code always exists.
    def notify
      ActiveRecord.after_all_transactions_commit do
        AccountMailer.with(account: account).email_otp.deliver_later
      end
    end
  end
end
