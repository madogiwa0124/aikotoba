# frozen_string_literal: true

require "test_helper"
require "minitest/mock"

class Aikotoba::Account::TwoFactor::EmailOtpTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper

  def setup
    @account = Aikotoba::Account.create_by!(attributes: {email: "email_otp@example.com", password: "password"})
  end

  def email_otp
    Aikotoba::Account::TwoFactor::EmailOtp.new(account: @account)
  end

  def issue_code!
    Aikotoba::Account::TwoFactor::EmailOtp.create_code!(account: @account, notify: false)
    @account.reload.email_otp_code
  end

  test "a code is six digits, zero padded, and expires after email_otp_code_expiry" do
    assert_match(/\A\d{6}\z/, Aikotoba::Account::TwoFactor::EmailOtpCode.generate_code)
    SecureRandom.stub(:random_number, 42) do
      assert_equal "000042", Aikotoba::Account::TwoFactor::EmailOtpCode.generate_code
    end
    freeze_time do
      assert_equal Aikotoba.email_otp_code_expiry.from_now, issue_code!.expired_at
    end
  end

  test "create_code! replaces the previous code and reports email_otp_code_issued" do
    first = issue_code!
    assert_event_reported("aikotoba.email_otp_code_issued", payload: {account_id: @account.id, notified: false}) do
      issue_code!
    end
    assert_equal 1, Aikotoba::Account::TwoFactor::EmailOtpCode.where(aikotoba_account_id: @account.id).count
    assert_not Aikotoba::Account::TwoFactor::EmailOtpCode.exists?(first.id)
  end

  test "create_code! with notify sends the code" do
    assert_emails 1 do
      Aikotoba::Account::TwoFactor::EmailOtp.create_code!(account: @account, notify: true)
    end
    assert_includes ActionMailer::Base.deliveries.last.body.to_s, @account.reload.email_otp_code.code
  end

  test "authenticate returns the account for the right code and consumes it" do
    code = issue_code!.code
    @account.update!(failed_attempts: 2)
    assert_equal @account, email_otp.authenticate(code)
    assert_nil @account.reload.email_otp_code
    assert_equal 0, @account.failed_attempts
  end

  test "authenticate counts a wrong code on the code and the account" do
    code = issue_code!
    assert_nil email_otp.authenticate(code.code.succ.last(6))
    assert_equal 1, code.reload.failed_attempts
    assert_equal 1, @account.reload.failed_attempts
  end

  test "authenticate does not count an attempt when no code can be tried" do
    assert_event_reported("aikotoba.email_otp_sign_in_failed", payload: {account_id: @account.id}) do
      assert_nil email_otp.authenticate("123456")
    end
    code = issue_code!
    code.update!(expired_at: 1.second.ago)
    assert_nil email_otp.authenticate(code.code)
    assert_equal 0, @account.reload.failed_attempts
  end

  test "challenge_active? is false once the code is used up or expired" do
    Aikotoba.config.email_otp_max_failed_attempts = 1
    code = issue_code!
    assert email_otp.challenge_active?
    email_otp.authenticate(code.code.succ.last(6))
    assert_not email_otp.challenge_active?
    assert_nil @account.reload.email_otp_code

    issue_code!.update!(expired_at: 1.second.ago)
    assert_not email_otp.challenge_active?
  end

  test "authenticate locks the account once failed_attempts goes over the limit" do
    Aikotoba.config.lockable = true
    Aikotoba.config.max_failed_attempts = 1
    code = issue_code!
    email_otp.authenticate(code.code.succ.last(6))
    assert_not @account.reload.locked?
    assert_event_reported("aikotoba.account_locked", payload: {account_id: @account.id}) do
      email_otp.authenticate(code.code.succ.last(6))
    end
    assert @account.reload.locked?
    assert_nil @account.email_otp_code
  end
end
