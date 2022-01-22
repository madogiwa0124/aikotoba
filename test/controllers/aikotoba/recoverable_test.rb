# frozen_string_literal: true

require "test_helper"
require "minitest/autorun"

class Aikotoba::RecoverableTest < ActionDispatch::IntegrationTest
  def setup
    Aikotoba.recoverable = true
    ActionController::Base.allow_forgery_protection = false
    email, password = ["email@example.com", "password"]
    @account = ::Aikotoba::Account.build_by(attributes: {email: email, password: password})
    @account.save!
  end

  def teardown
    Aikotoba.recoverable = false
  end

  test "success GET new_recovery_token_path" do
    get aikotoba.new_recovery_token_path
    assert_equal 200, status
    assert_select "h1", I18n.t(".aikotoba.recoveries.new")
  end

  test "success POST create_recovery_token_path" do
    assert_emails 1 do
      post aikotoba.create_recovery_token_path, params: {account: {email: @account.email}}
    end
    assert_redirected_to aikotoba.new_session_path
    assert_equal I18n.t(".aikotoba.messages.recovery.sent"), flash[:notice]
    recover_email = ActionMailer::Base.deliveries.last
    assert_equal I18n.t(".aikotoba.mailers.recover.subject"), recover_email.subject
    assert_equal [@account.email], recover_email.to
    assert_match(/Password reset URL:/, recover_email.body.to_s)
    assert_includes(recover_email.body.to_s, @account.reload.recovery_token.token)
  end

  test "regenerated token when success POST create_recovery_token_path " do
    @account.build_recovery_token.save!
    @account.recovery_token.update!(token: "before_token", expired_at: 1.day.ago)
    post aikotoba.create_recovery_token_path, params: {account: {email: @account.email}}
    @account.recovery_token.reload
    assert @account.recovery_token.token.present?
    assert @account.recovery_token.expired_at.future?
    assert_not_equal @account.recovery_token.token, "before_token"
  end

  test "failed POST create_recovery_token_path by not exist account" do
    assert_emails 0 do
      post aikotoba.create_recovery_token_path, params: {account: {email: "not_found@example.com"}}
    end
    assert_equal status, 422
    assert_equal I18n.t(".aikotoba.messages.recovery.sent_failed"), flash[:alert]
  end

  test "success GET edit_account_password_path by active token" do
    @account.build_recovery_token.save!
    get aikotoba.edit_account_password_path(token: @account.recovery_token.token)
    assert_equal 200, status
    assert_select "h1", I18n.t(".aikotoba.recoveries.edit")
  end

  test "failed GET edit_account_password_path by expired token" do
    @account.build_recovery_token.save!
    @account.recovery_token.update!(expired_at: 1.hour.ago)
    get aikotoba.update_account_password_path(token: @account.recovery_token.token)
    assert_equal status, 404
  end

  test "failed GET edit_account_password_path by not found token" do
    @account.build_recovery_token.save!
    get aikotoba.edit_account_password_path(token: "not found token")
    assert_equal status, 404
  end

  test "failed GET edit_account_password_path by nil token" do
    assert_raises(ActionController::UrlGenerationError) do
      get aikotoba.edit_account_password_path(token: nil)
    end
  end

  test "success PATCH update_account_password_path by valid password" do
    @account.build_recovery_token.save!
    patch aikotoba.update_account_password_path(token: @account.recovery_token.token, account: {password: "updated_password"})
    assert_redirected_to aikotoba.new_session_path
    assert_equal I18n.t(".aikotoba.messages.recovery.success"), flash[:notice]
    assert_nil @account.reload.recovery_token
    updated_account = ::Aikotoba::Account.authenticate_by(attributes: {email: @account.email, password: "updated_password"})
    assert_equal updated_account.id, @account.id
  end

  test "faild PATCH update_account_password_path by invalid password" do
    @account.build_recovery_token.save!
    patch aikotoba.update_account_password_path(token: @account.recovery_token.token, account: {password: "short"})
    assert_equal I18n.t(".aikotoba.messages.recovery.failed"), flash[:alert]
    messages = @controller.instance_variable_get(:@account).errors.full_messages
    assert_includes messages, "Password is invalid."
  end

  test "failed PATCH update_account_password_path by not found token" do
    @account.build_recovery_token.save!
    patch aikotoba.update_account_password_path(token: "not found token", account: {password: "password"})
    assert_equal 404, status
  end

  test "failed PATCH edit_account_password_path by nil token" do
    assert_raises(ActionController::UrlGenerationError) do
      patch aikotoba.update_account_password_path(token: nil, account: {password: "password"})
    end
  end

  test "Recoverable path to 404 when Aikotoba.recoverable is false" do
    Aikotoba.recoverable = false
    @account.build_recovery_token.save!
    get aikotoba.new_recovery_token_path
    assert_equal 404, status
    get aikotoba.edit_account_password_path(token: @account.recovery_token.token)
    assert_equal 404, status
  end
end
