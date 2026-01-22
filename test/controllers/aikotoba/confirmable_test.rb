# frozen_string_literal: true

require "test_helper"
require "minitest/autorun"

class Aikotoba::ConfirmableTest < ActionDispatch::IntegrationTest
  def setup
    Aikotoba.confirmable = true
    ActionController::Base.allow_forgery_protection = false
    email, password = ["email@example.com", "password"]
    @account = ::Aikotoba::Account.build_by(attributes: {email: email, password: password})
    @account.confirmed = false
    @account.save!
    @account.build_confirmation_token.save!
  end

  def teardown
    Aikotoba.confirmable = false
  end

  test "success GET new_confirmation_token" do
    get aikotoba.new_confirmation_token_path
    assert_equal 200, status
    assert_select "h1", I18n.t(".aikotoba.confirms.new")
  end

  test "success POST create_confirmation_token_path" do
    assert_emails 1 do
      post aikotoba.create_confirmation_token_path, params: {account: {email: @account.email}}
    end
    assert_redirected_to aikotoba.new_session_path
    assert_equal I18n.t(".aikotoba.messages.confirmation.sent"), flash[:notice]
    confirm_email = ActionMailer::Base.deliveries.last
    assert_equal I18n.t(".aikotoba.mailers.confirm.subject"), confirm_email.subject
    assert_equal @account.email, confirm_email.to[0]
    assert_match(/Confirm url:/, confirm_email.body.to_s)
    assert_match(/The url expires at/, confirm_email.body.to_s)
    assert_includes(confirm_email.body.to_s, @account.reload.confirmation_token.token)
    assert_includes(confirm_email.body.to_s, I18n.l(@account.confirmation_token.expired_at, format: :long))
  end

  test "regenerated token when success POST create_confirmation_token_path " do
    @account.build_confirmation_token.save!
    @account.confirmation_token.update!(token: "before_token", expired_at: 1.day.ago)
    post aikotoba.create_confirmation_token_path, params: {account: {email: @account.email}}
    assert_redirected_to aikotoba.new_session_path
    assert_equal I18n.t(".aikotoba.messages.confirmation.sent"), flash[:notice]
    @account.reload
    assert @account.confirmation_token.token.present?
    assert @account.confirmation_token.expired_at.future?
    assert_not_equal @account.confirmation_token.token, "before_token"
  end

  test "failed POST create_confirmation_token_path by not exist account" do
    assert_emails 0 do
      post aikotoba.create_confirmation_token_path, params: {account: {email: "not_found@example.com"}}
    end
    assert_redirected_to aikotoba.new_session_path
    assert_equal I18n.t(".aikotoba.messages.confirmation.sent"), flash[:notice]
  end

  test "failed POST create_confirmation_token_path by confirmed account" do
    @account.confirm!
    assert_emails 0 do
      post aikotoba.create_confirmation_token_path, params: {account: {email: @account.email}}
    end
    assert_redirected_to aikotoba.new_session_path
    assert_equal I18n.t(".aikotoba.messages.confirmation.sent"), flash[:notice]
  end

  test "success GET confirm_account_path by active token" do
    get aikotoba.confirm_account_path(token: @account.confirmation_token.token)
    assert_redirected_to aikotoba.new_session_path
    assert_equal I18n.t(".aikotoba.messages.confirmation.success"), flash[:notice]
    assert_equal @account.reload.confirmed?, true
    assert_nil @account.reload.confirmation_token
  end

  test "failed GET confirm_account_path by not exists token" do
    get aikotoba.confirm_account_path(token: "not_exists_token")
    assert_equal status, 404
  end

  test "failed GET confirm_account_path by expired token" do
    @account.confirmation_token.update!(expired_at: 1.hour.ago)
    get aikotoba.confirm_account_path(token: @account.confirmation_token.token)
    assert_equal status, 404
  end

  test "faild GET confirm_account_path by nil token" do
    assert_raises(ActionController::UrlGenerationError) do
      get aikotoba.confirm_account_path(token: nil)
    end
  end

  test "success POST create_account_path with comfirm token send" do
    Aikotoba.registerable = true
    post aikotoba.create_account_path, params: {account: {email: "bar@example.com", password: "password"}}
    assert_redirected_to aikotoba.new_session_path
    assert_equal I18n.t(".aikotoba.messages.registration.success"), flash[:notice]
    account = @controller.instance_variable_get(:@account)
    confirm_email = ActionMailer::Base.deliveries.last
    assert_equal I18n.t(".aikotoba.mailers.confirm.subject"), confirm_email.subject
    assert_equal account.email, confirm_email.to[0]
    assert_match(/Confirm url:/, confirm_email.body.to_s)
    assert_includes(confirm_email.body.to_s, account.reload.confirmation_token.token)
    Aikotoba.registerable = false
  end

  test "success POST new_session_path by comfirmed account" do
    get aikotoba.confirm_account_path(token: @account.confirmation_token.token)
    post aikotoba.new_session_path, params: {account: {email: @account.email, password: @account.password}}
    assert_redirected_to Aikotoba.default_scope[:after_sign_in_path]
    assert_equal I18n.t(".aikotoba.messages.authentication.success"), flash[:notice]
  end

  test "failed POST new_session_path by not comfirmed account" do
    post aikotoba.new_session_path, params: {account: {email: @account.email, password: @account.password}}
    assert_equal status, 422
    assert_equal I18n.t(".aikotoba.messages.authentication.failed"), flash[:alert]
  end

  test "Confirmable path to 404 when Aikotoba.confirmable is false" do
    Aikotoba.confirmable = false
    get aikotoba.new_confirmation_token_path
    assert_equal 404, status
    get aikotoba.confirm_account_path(token: @account.confirmation_token)
    assert_equal 404, status
    post aikotoba.create_confirmation_token_path, params: {account: {email: @account.email}}
    assert_equal 404, status
  end
end
