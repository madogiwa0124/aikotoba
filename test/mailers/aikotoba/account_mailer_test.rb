# frozen_string_literal: true

require "test_helper"

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

  test "unlock sends nothing once the token is gone" do
    Aikotoba::Account::Lock.create_unlock_token!(account: @account, notify: false)
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
end
