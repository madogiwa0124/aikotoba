# frozen_string_literal: true

require "test_helper"
require "minitest/autorun"

class Aikotoba::RecoverableTest < ActionDispatch::IntegrationTest
  def setup
    Aikotoba.enable_recover = true
    ActionController::Base.allow_forgery_protection = false
    email, password = ["email@example.com", "password"]
    @account = ::Aikotoba::Account.build_account_by(attributes: {email: email, password: password})
    @account.save!
  end

  def teardown
    Aikotoba.enable_recover = false
  end

  test "success GET recoverable_new_path" do
    get aikotoba.recoverable_new_path
    assert_equal 200, status
    assert_select "h1", I18n.t(".aikotoba.recoveries.new")
  end

  test "success POST recoverable_create_path" do
    assert_emails 1 do
      post aikotoba.recoverable_create_path, params: {account: {email: @account.email}}
    end
    assert_redirected_to Aikotoba.sign_in_path
    assert_equal I18n.t(".aikotoba.messages.recovery.sent"), flash[:notice]
    recover_email = ActionMailer::Base.deliveries.last
    assert_equal I18n.t(".aikotoba.mailers.recover.subject"), recover_email.subject
    assert_equal [@account.email], recover_email.to
    assert_match(/Password reset URL:/, recover_email.body.to_s)
    assert_includes(recover_email.body.to_s, @account.reload.recover_token)
  end

  test "failed POST recoverable_create_path by not exist account" do
    assert_emails 0 do
      post aikotoba.recoverable_create_path, params: {account: {email: "not_found@example.com"}}
    end
    assert_redirected_to Aikotoba.sign_in_path
    assert_equal I18n.t(".aikotoba.messages.recovery.sent_failed"), flash[:alert]
  end

  test "success GET recoverable_edit_path" do
    @account.update_recover_token!
    get aikotoba.recoverable_edit_path(token: @account.recover_token)
    assert_equal 200, status
    assert_select "h1", I18n.t(".aikotoba.recoveries.edit")
  end

  test "failed GET confirmable_confirm_path by not found token" do
    @account.update_recover_token!
    get aikotoba.recoverable_edit_path(token: "not found token")
    assert_equal status, 404
  end

  test "success PATCH recoverable_update_path by valid password" do
    @account.update_recover_token!
    patch aikotoba.recoverable_update_path(token: @account.recover_token, account: {password: "updated_password"})
    assert_redirected_to Aikotoba.sign_in_path
    assert_equal I18n.t(".aikotoba.messages.recovery.success"), flash[:notice]
    assert_nil @account.reload.recover_token
    updated_account = ::Aikotoba::Account.find_account_by(attributes: {email: @account.email, password: "updated_password"})
    assert_equal updated_account.id, @account.id
  end

  test "faild PATCH recoverable_update_path by invalid password" do
    @account.update_recover_token!
    patch aikotoba.recoverable_update_path(token: @account.recover_token, account: {password: "short"})
    assert_equal I18n.t(".aikotoba.messages.recovery.failed"), flash[:alert]
    messages = @controller.instance_variable_get(:@account).errors.full_messages
    assert_includes messages, "Password is too short (minimum is 8 characters)"
  end

  test "Recoverable path to 404 when Aikotoba.enable_recover is false" do
    Aikotoba.enable_recover = false
    @account.update_recover_token!
    get aikotoba.recoverable_new_path
    assert_equal 404, status
    get aikotoba.recoverable_edit_path(token: @account.recover_token)
    assert_equal 404, status
  end
end