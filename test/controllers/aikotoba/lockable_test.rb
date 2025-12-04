# frozen_string_literal: true

require "test_helper"
require "minitest/autorun"

class Aikotoba::LockableTest < ActionDispatch::IntegrationTest
  def setup
    ActionController::Base.allow_forgery_protection = false
    Aikotoba.lockable = true
    Aikotoba.max_failed_attempts = 2
    email, password = ["email@example.com", "password"]
    @account = ::Aikotoba::Account.build_by(attributes: {email: email, password: password})
    @account.save!
  end

  def teardown
    Aikotoba.lockable = false
  end

  test "success GET new_unlock_token_path" do
    get aikotoba.new_unlock_token_path
    assert_equal 200, status
    assert_select "h1", I18n.t(".aikotoba.unlocks.new")
  end

  test "success POST create_unlock_token_path" do
    Aikotoba::Account::Lock.lock!(account: @account)
    assert_emails 1 do
      post aikotoba.create_unlock_token_path, params: {account: {email: @account.email}}
    end
    assert_redirected_to aikotoba.new_session_path
    assert_equal I18n.t(".aikotoba.messages.unlocking.sent"), flash[:notice]
    unlock_email = ActionMailer::Base.deliveries.last
    assert_equal I18n.t(".aikotoba.mailers.unlock.subject"), unlock_email.subject
    assert_equal @account.email, unlock_email.to[0]
    assert_match(/Unlock url:/, unlock_email.body.to_s)
    assert_match(/The url expires at/, unlock_email.body.to_s)
    assert_includes(unlock_email.body.to_s, @account.reload.unlock_token.token)
    assert_includes(unlock_email.body.to_s, I18n.l(@account.reload.unlock_token.expired_at, format: :long))
  end

  test "regenerated token when success POST create_unlock_token_path " do
    Aikotoba::Account::Lock.lock!(account: @account)
    @account.unlock_token.update!(token: "before_token", expired_at: 1.day.ago)
    post aikotoba.create_unlock_token_path, params: {account: {email: @account.email}}
    @account.reload
    assert @account.unlock_token.token.present?
    assert @account.unlock_token.expired_at.future?
    assert_not_equal @account.unlock_token.token, "before_token"
  end

  test "failed POST create_unlock_token_path due to not exist account" do
    assert_emails 0 do
      post aikotoba.create_unlock_token_path, params: {account: {email: "not_found@example.com"}}
    end
    assert_equal status, 422
    assert_equal I18n.t(".aikotoba.messages.unlocking.failed"), flash[:alert]
  end

  test "failed POST create_unlock_token_path due to not locked account" do
    Aikotoba::Account::Lock.lock!(account: @account)
    assert_emails 0 do
      post aikotoba.create_unlock_token_path, params: {account: {email: "not_found@example.com"}}
    end
    assert_equal status, 422
    assert_equal I18n.t(".aikotoba.messages.unlocking.failed"), flash[:alert]
  end

  test "success GET unlock_account_path by active token" do
    @account.update!(failed_attempts: 3)
    Aikotoba::Account::Lock.lock!(account: @account)
    get aikotoba.unlock_account_path(token: @account.reload.unlock_token.token)
    assert_redirected_to aikotoba.new_session_path
    assert_equal I18n.t(".aikotoba.messages.unlocking.success"), flash[:notice]
    assert_equal @account.reload.locked?, false
    assert_nil @account.reload.unlock_token
    assert_equal @account.reload.failed_attempts, 0
  end

  test "failed GET unlock_account_path by expired token" do
    Aikotoba::Account::Lock.lock!(account: @account)
    @account.unlock_token.update!(expired_at: 1.hour.ago)
    get aikotoba.unlock_account_path(token: @account.unlock_token.token)
    assert_equal status, 404
  end

  test "failed GET unlock_account_path by not exists token" do
    get aikotoba.unlock_account_path(token: "not_exists_token")
    assert_equal status, 404
  end

  test "faild GET unlock_account_path by nil token" do
    assert_raises(ActionController::UrlGenerationError) do
      get aikotoba.unlock_account_path(token: nil)
    end
  end

  test "account locked with sent unlock mail when failed POST new_session_path exceed max failed attempts." do
    Aikotoba::Account::Lock.unlock!(account: @account)
    post aikotoba.new_session_path, params: {account: {email: @account.email, password: "wrong password"}}
    post aikotoba.new_session_path, params: {account: {email: @account.email, password: "wrong password"}}
    assert_equal @account.reload.locked?, false
    assert_equal @account.reload.failed_attempts, 2

    assert_emails 1 do
      post aikotoba.new_session_path, params: {account: {email: @account.email, password: "wrong password"}}
      assert_equal @account.reload.locked?, true
      assert_equal @account.reload.failed_attempts, 3
      assert_equal status, 422
      assert_equal I18n.t(".aikotoba.messages.authentication.failed"), flash[:alert]
    end

    unlock_email = ActionMailer::Base.deliveries.last
    assert_equal I18n.t(".aikotoba.mailers.unlock.subject"), unlock_email.subject
    assert_equal @account.email, unlock_email.to[0]
    assert_match(/Unlock url:/, unlock_email.body.to_s)
    assert_includes(unlock_email.body.to_s, @account.reload.unlock_token.token)
  end

  test "failed POST new_session_path by locked accout." do
    Aikotoba::Account::Lock.lock!(account: @account)
    post aikotoba.new_session_path, params: {account: {email: @account.email, password: "password"}}
    assert_equal status, 422
    assert_equal I18n.t(".aikotoba.messages.authentication.failed"), flash[:alert]
  end

  test "succes POST new_session_path by unlocked accout." do
    Aikotoba::Account::Lock.unlock!(account: @account)
    post aikotoba.new_session_path, params: {account: {email: @account.email, password: "password"}}
    assert_redirected_to Aikotoba.default_scope[:after_sign_in_path]
    assert_equal I18n.t(".aikotoba.messages.authentication.success"), flash[:notice]
  end

  test "reset lock status when succes POST new_session_path." do
    Aikotoba::Account::Lock.unlock!(account: @account)
    post aikotoba.new_session_path, params: {account: {email: @account.email, password: "wrong password"}}
    assert_equal @account.reload.failed_attempts, 1
    post aikotoba.new_session_path, params: {account: {email: @account.email, password: "password"}}
    assert_redirected_to Aikotoba.default_scope[:after_sign_in_path]
    assert_equal I18n.t(".aikotoba.messages.authentication.success"), flash[:notice]
    assert_equal @account.reload.failed_attempts, 0
  end
end
