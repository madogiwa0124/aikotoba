# frozen_string_literal: true

require "test_helper"

# NOTE: Every token email is sent from the record's #notify inside
#       ActiveRecord.after_all_transactions_commit: it waits for the caller's outer
#       transaction to commit and is dropped on rollback, so a sent link or code always exists.
#       The assertions look at enqueued jobs, not performed deliveries, on purpose: AccountMailer
#       sends nothing when the token is gone by the time the job runs, so a mail enqueued before
#       a rollback would still deliver nothing and assert_emails could not tell the difference.
class Aikotoba::TokenEmailCommitTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper

  CASES = {
    confirmation_token: {
      create: ->(account) { Aikotoba::Account::Confirmation.create_token!(account: account, notify: true) },
      record_class: "Aikotoba::Account::ConfirmationToken",
      mail: :confirm
    },
    unlock_token: {
      create: ->(account) { Aikotoba::Account::Lock.create_token!(account: account, notify: true) },
      record_class: "Aikotoba::Account::UnlockToken",
      mail: :unlock
    },
    recovery_token: {
      create: ->(account) { Aikotoba::Account::Recovery.create_token!(account: account, notify: true) },
      record_class: "Aikotoba::Account::RecoveryToken",
      mail: :recover
    },
    email_otp_code: {
      create: ->(account) { Aikotoba::Account::TwoFactor::EmailOtp.create_code!(account: account, notify: true) },
      record_class: "Aikotoba::Account::TwoFactor::EmailOtpCode",
      mail: :email_otp
    }
  }.freeze

  def setup
    @account = Aikotoba::Account.create!(email: "user@example.com", confirmed: true, locked: false)
  end

  CASES.each do |name, spec|
    test "#{name}: no email is enqueued and no row is left when the caller's transaction rolls back" do
      ActiveRecord::Base.transaction do
        spec[:create].call(@account)
        raise ActiveRecord::Rollback
      end

      assert_no_enqueued_emails
      assert_not spec[:record_class].constantize.exists?(aikotoba_account_id: @account.id)
    end

    test "#{name}: the email waits for the caller's outer transaction and is enqueued once it commits" do
      ActiveRecord::Base.transaction do
        spec[:create].call(@account)
        assert_no_enqueued_emails
      end

      assert_enqueued_emails 1
      assert_enqueued_email_with Aikotoba::AccountMailer, spec[:mail], params: {account: @account}
      assert spec[:record_class].constantize.exists?(aikotoba_account_id: @account.id)
    end
  end
end
