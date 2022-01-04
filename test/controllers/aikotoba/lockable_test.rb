# frozen_string_literal: true

require "test_helper"
require "minitest/autorun"

class Aikotoba::LockableTest < ActionDispatch::IntegrationTest
  def setup
    ActionController::Base.allow_forgery_protection = false
    Aikotoba.enable_lock = true
    Aikotoba.max_failed_attempts = 2
    email, password = ["email@example.com", "password"]
    @account = ::Aikotoba::Account.build_by(attributes: {email: email, password: password})
    @account.save!
  end

  def teardown
    Aikotoba.enable_lock = false
  end

  test "success GET lockable_new_path" do
    get aikotoba.lockable_new_path
    assert_equal 200, status
    assert_select "h1", I18n.t(".aikotoba.unlocks.new")
  end

  test "success POST lockable_create_path" do
    Aikotoba::Account::Lock.lock!(account: @account)
    assert_emails 1 do
      post aikotoba.lockable_create_path, params: {account: {email: @account.email}}
    end
    assert_redirected_to Aikotoba.sign_in_path
    assert_equal I18n.t(".aikotoba.messages.unlocking.sent"), flash[:notice]
    unlock_email = ActionMailer::Base.deliveries.last
    assert_equal I18n.t(".aikotoba.mailers.unlock.subject"), unlock_email.subject
    assert_equal @account.email, unlock_email.to[0]
    assert_match(/Unlock URL:/, unlock_email.body.to_s)
    assert_includes(unlock_email.body.to_s, @account.reload.unlock_token.token)
  end

  test "failed POST lockable_create_path due to not exist account" do
    assert_emails 0 do
      post aikotoba.lockable_create_path, params: {account: {email: "not_found@example.com"}}
    end
    assert_redirected_to Aikotoba.unlock_path
    assert_equal I18n.t(".aikotoba.messages.unlocking.failed"), flash[:alert]
  end

  test "failed POST lockable_create_path due to not locked account" do
    Aikotoba::Account::Lock.lock!(account: @account)
    assert_emails 0 do
      post aikotoba.lockable_create_path, params: {account: {email: "not_found@example.com"}}
    end
    assert_redirected_to Aikotoba.unlock_path
    assert_equal I18n.t(".aikotoba.messages.unlocking.failed"), flash[:alert]
  end

  test "success GET lockable_unlock_path" do
    @account.update!(failed_attempts: 3)
    Aikotoba::Account::Lock.lock!(account: @account)
    get aikotoba.lockable_unlock_path(token: @account.reload.unlock_token.token)
    assert_redirected_to Aikotoba.sign_in_path
    assert_equal I18n.t(".aikotoba.messages.unlocking.success"), flash[:notice]
    assert_equal @account.reload.locked?, false
    assert_nil @account.reload.unlock_token
    assert_equal @account.reload.failed_attempts, 0
  end

  test "faild GET lockable_unlock_path by nil token" do
    assert_raises(ActionController::UrlGenerationError) do
      get aikotoba.lockable_unlock_path(token: nil)
    end
  end

  test "account locked with sent unlock mail when failed POST sign_in_path exceed max failed attempts." do
    Aikotoba::Account::Lock.unlock!(account: @account)
    post aikotoba.sign_in_path, params: {account: {email: @account.email, password: "wrong password"}}
    post aikotoba.sign_in_path, params: {account: {email: @account.email, password: "wrong password"}}
    assert_equal @account.reload.locked?, false
    assert_equal @account.reload.failed_attempts, 2

    assert_emails 1 do
      post aikotoba.sign_in_path, params: {account: {email: @account.email, password: "wrong password"}}
      assert_equal @account.reload.locked?, true
      assert_equal @account.reload.failed_attempts, 3
      assert_redirected_to Aikotoba.failed_sign_in_path
      assert_equal I18n.t(".aikotoba.messages.authentication.failed"), flash[:alert]
    end

    unlock_email = ActionMailer::Base.deliveries.last
    assert_equal I18n.t(".aikotoba.mailers.unlock.subject"), unlock_email.subject
    assert_equal @account.email, unlock_email.to[0]
    assert_match(/Unlock URL:/, unlock_email.body.to_s)
    assert_includes(unlock_email.body.to_s, @account.reload.unlock_token.token)
  end

  test "failed POST sign_in_path by locked accout." do
    Aikotoba::Account::Lock.lock!(account: @account)
    post aikotoba.sign_in_path, params: {account: {email: @account.email, password: "password"}}
    assert_redirected_to Aikotoba.failed_sign_in_path
    assert_equal I18n.t(".aikotoba.messages.authentication.failed"), flash[:alert]
  end

  test "succes POST sign_in_path by unlocked accout." do
    Aikotoba::Account::Lock.unlock!(account: @account)
    post aikotoba.sign_in_path, params: {account: {email: @account.email, password: "password"}}
    assert_redirected_to Aikotoba.after_sign_in_path
    assert_equal I18n.t(".aikotoba.messages.authentication.success"), flash[:notice]
  end

  test "reset lock status when succes POST sign_in_path." do
    Aikotoba::Account::Lock.unlock!(account: @account)
    post aikotoba.sign_in_path, params: {account: {email: @account.email, password: "wrong password"}}
    assert_equal @account.reload.failed_attempts, 1
    post aikotoba.sign_in_path, params: {account: {email: @account.email, password: "password"}}
    assert_redirected_to Aikotoba.after_sign_in_path
    assert_equal I18n.t(".aikotoba.messages.authentication.success"), flash[:notice]
    assert_equal @account.reload.failed_attempts, 0
  end
end
