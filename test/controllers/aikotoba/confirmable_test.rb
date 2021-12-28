# frozen_string_literal: true

require "test_helper"
require "minitest/autorun"

class Aikotoba::ConfirmableTest < ActionDispatch::IntegrationTest
  def setup
    Aikotoba.enable_confirm = true
    ActionController::Base.allow_forgery_protection = false
    email, password = ["email@example.com", "password"]
    @account = ::Aikotoba::Account.build_account_by({"strategy" => :email_password, "email" => email, "password" => password})
    @account.confirmed = false
    @account.confirm_token = SecureRandom.hex(32)
    @account.save!
  end

  def teardown
    Aikotoba.enable_confirm = false
  end

  test "success GET confirmable_new_path" do
    get aikotoba.confirmable_new_path
    assert_equal 200, status
    assert_select "h1", I18n.t(".aikotoba.confirms.new")
  end

  test "success POST confirmable_create_path" do
    assert_emails 1 do
      post aikotoba.confirmable_create_path, params: {account: {email: @account.email}}
    end
    assert_redirected_to Aikotoba.sign_up_path
    assert_equal I18n.t(".aikotoba.messages.confirmation.sent"), flash[:notice]
    confirm_email = ActionMailer::Base.deliveries.last
    assert_equal I18n.t(".aikotoba.mailers.confirm.subject"), confirm_email.subject
    assert_equal @account.email, confirm_email.to[0]
    assert_match(/Confirm URL:/, confirm_email.body.to_s)
    assert_includes(confirm_email.body.to_s, @account.reload.confirm_token)
  end

  test "failed POST confirmable_create_path due to not exist account" do
    assert_emails 0 do
      post aikotoba.confirmable_create_path, params: {account: {email: "not_found@example.com"}}
    end
    assert_redirected_to Aikotoba.sign_up_path
    assert_equal I18n.t(".aikotoba.messages.confirmation.failed"), flash[:alert]
  end

  test "success GET confirmable_confirm_path" do
    get aikotoba.confirmable_confirm_path(token: @account.confirm_token)
    assert_redirected_to Aikotoba.sign_in_path
    assert_equal I18n.t(".aikotoba.messages.confirmation.success"), flash[:notice]
    assert_equal @account.reload.confirmed?, true
  end

  test "success POST sign_up_path with comfirm token send" do
    post aikotoba.sign_up_path, params: {account: {strategy: :email_password, email: "bar@example.com", password: "pass"}}
    assert_redirected_to Aikotoba.after_sign_up_path
    assert_equal I18n.t(".aikotoba.messages.registration.strategies.email_password.success"), flash[:notice]
    account = @controller.instance_variable_get("@account")
    confirm_email = ActionMailer::Base.deliveries.last
    assert_equal I18n.t(".aikotoba.mailers.confirm.subject"), confirm_email.subject
    assert_equal account.email, confirm_email.to[0]
    assert_match(/Confirm URL:/, confirm_email.body.to_s)
    assert_includes(confirm_email.body.to_s, account.confirm_token)
  end

  test "success POST sign_in_path by comfirmed account" do
    get aikotoba.confirmable_confirm_path(token: @account.confirm_token)
    post aikotoba.sign_in_path, params: {account: {strategy: :email_password, email: @account.email, password: @account.password}}
    assert_redirected_to Aikotoba.after_sign_in_path
    assert_equal I18n.t(".aikotoba.messages.authentication.success"), flash[:notice]
  end

  test "failed POST sign_in_path by not comfirmed account" do
    post aikotoba.sign_in_path, params: {account: {strategy: :email_password, email: @account.email, password: @account.password}}
    assert_redirected_to Aikotoba.failed_sign_in_path
    assert_equal I18n.t(".aikotoba.messages.authentication.failed"), flash[:alert]
  end

  test "Confirmable path to 404 when Aikotoba.enable_confirm is false" do
    Aikotoba.enable_confirm = false
    get aikotoba.confirmable_new_path
    assert_equal 404, status
    get aikotoba.confirmable_confirm_path(token: @account.confirm_token)
    assert_equal 404, status
    post aikotoba.confirmable_create_path, params: {account: {email: @account.email}}
    assert_equal 404, status
  end
end
