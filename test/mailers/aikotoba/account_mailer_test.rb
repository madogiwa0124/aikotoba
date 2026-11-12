# frozen_string_literal: true

require "test_helper"
require "minitest/mock"

class Aikotoba::AccountMailerTest < ActionMailer::TestCase
  def setup
    @account = Aikotoba::Account.create_by!(attributes: {email: "mailer@example.com", password: "password"})
  end

  {
    confirm: Aikotoba::Account::Confirmation,
    recover: Aikotoba::Account::Recovery,
    magic_link: Aikotoba::Account::MagicLink
  }.each do |mail, owner|
    test "#{mail} sends nothing once the token is gone" do
      owner.create_token!(account: @account, notify: false)
      @account.public_send(:"#{owner.name.demodulize.underscore}_token").destroy!
      assert_no_emails do
        Aikotoba::AccountMailer.with(account: @account.reload).public_send(mail).deliver_now
      end
    end
  end

  test "email_otp sends nothing once the code is gone" do
    Aikotoba::Account::TwoFactor::EmailOtp.create_code!(account: @account, notify: false)
    @account.email_otp_code.destroy!
    assert_no_emails do
      Aikotoba::AccountMailer.with(account: @account.reload).email_otp.deliver_now
    end
  end

  test "email_otp sends the account's current code, with no link" do
    Aikotoba::Account::TwoFactor::EmailOtp.create_code!(account: @account, notify: false)
    mail = Aikotoba::AccountMailer.with(account: @account.reload).email_otp.deliver_now
    assert_equal [@account.email], mail.to
    assert_includes mail.body.to_s, @account.email_otp_code.code
    assert_includes mail.body.to_s, I18n.l(@account.email_otp_code.expired_at, format: :long)
    assert_no_match(/https?:/, mail.body.to_s)
  end

  test "unlock sends nothing once the token is gone" do
    Aikotoba::Account::Lock.create_token!(account: @account, notify: false)
    @account.unlock_token.destroy!
    assert_no_emails do
      Aikotoba::AccountMailer.with(account: @account.reload).unlock.deliver_now
    end
  end

  test "renders the account's current token when a newer one replaced the enqueued one" do
    Aikotoba::Account::Recovery.create_token!(account: @account, notify: false)
    first = @account.recovery_token.token
    Aikotoba::Account::Recovery.create_token!(account: @account, notify: false)
    latest = @account.reload.recovery_token.token
    assert_not_equal first, latest
    assert_equal 1, Aikotoba::Account::RecoveryToken.where(aikotoba_account_id: @account.id).count

    mail = Aikotoba::AccountMailer.with(account: @account).recover.deliver_now
    assert_includes mail.body.to_s, latest
    assert_not_includes mail.body.to_s, first
  end

  test "refuses to call anything but an engine route helper" do
    Aikotoba::Account::Confirmation.create_token!(account: @account, notify: false)
    Aikotoba.scopes.stub(:name_for, "unknown") do
      error = assert_raises(ArgumentError) do
        Aikotoba::AccountMailer.with(account: @account).confirm.deliver_now
      end
      assert_match "unknown_confirm_account_url", error.message
    end

    mailer = Aikotoba::AccountMailer.new
    mailer.instance_variable_set(:@account, @account)
    assert_raises(ArgumentError) { mailer.send(:aikotoba_scoped_url, :routes) }
  end
end
