# frozen_string_literal: true

require "test_helper"
require "minitest/autorun"

class Aikotoba::MagicLinkableTest < ActionDispatch::IntegrationTest
  def setup
    Aikotoba.magic_link_authenticatable = true
    ActionController::Base.allow_forgery_protection = false
    @account = ::Aikotoba::Account.create!(email: "email@example.com", confirmed: true)
  end

  def teardown
    Aikotoba.magic_link_authenticatable = false
  end

  test "account has no password" do
    assert_nil @account.password_hash
  end

  test "success GET new_magic_link_path" do
    get aikotoba.new_magic_link_path
    assert_equal 200, status
    assert_select "h1", I18n.t(".aikotoba.magic_links.new")
  end

  test "success POST create_magic_link_path" do
    assert_emails 1 do
      post aikotoba.create_magic_link_path, params: {account: {email: @account.email}}
    end
    assert_redirected_to aikotoba.new_session_path
    assert_equal I18n.t(".aikotoba.messages.magic_link.sent"), flash[:notice]
    magic_link_email = ActionMailer::Base.deliveries.last
    assert_equal I18n.t(".aikotoba.mailers.magic_link.subject"), magic_link_email.subject
    assert_equal @account.email, magic_link_email.to[0]
    assert_match(/Sign in url:/, magic_link_email.body.to_s)
    assert_match(/The url expires at/, magic_link_email.body.to_s)
    assert_includes(magic_link_email.body.to_s, @account.reload.magic_link_token.token)
    assert_includes(magic_link_email.body.to_s, I18n.l(@account.magic_link_token.expired_at, format: :long))
  end

  test "regenerated token when success POST create_magic_link_path" do
    Aikotoba::Account::MagicLink.create_token!(account: @account, notify: false)
    @account.magic_link_token.update!(token: "before_token", expired_at: 1.day.ago)
    post aikotoba.create_magic_link_path, params: {account: {email: @account.email}}
    assert_redirected_to aikotoba.new_session_path
    assert_equal I18n.t(".aikotoba.messages.magic_link.sent"), flash[:notice]
    @account.reload
    assert @account.magic_link_token.token.present?
    assert @account.magic_link_token.expired_at.future?
    assert_not_equal @account.magic_link_token.token, "before_token"
  end

  test "failed POST create_magic_link_path by not exist account" do
    assert_emails 0 do
      post aikotoba.create_magic_link_path, params: {account: {email: "not_found@example.com"}}
    end
    assert_redirected_to aikotoba.new_session_path
    assert_equal I18n.t(".aikotoba.messages.magic_link.sent"), flash[:notice]
  end

  test "success GET authenticate_via_magic_link_path by active token" do
    Aikotoba::Account::MagicLink.create_token!(account: @account, notify: false)
    get aikotoba.authenticate_via_magic_link_path(token: @account.magic_link_token.token)
    assert_redirected_to Aikotoba.default_scope[:after_sign_in_path]
    assert_equal I18n.t(".aikotoba.messages.authentication.success"), flash[:notice]
    assert_nil @account.reload.magic_link_token
  end

  test "success GET authenticate_via_magic_link_path establishes a session" do
    Aikotoba::Account::MagicLink.create_token!(account: @account, notify: false)
    get aikotoba.authenticate_via_magic_link_path(token: @account.magic_link_token.token)
    get aikotoba.new_session_path
    assert_redirected_to Aikotoba.default_scope[:after_sign_in_path]
  end

  test "failed GET authenticate_via_magic_link_path by not exists token" do
    get aikotoba.authenticate_via_magic_link_path(token: "not_exists_token")
    assert_equal status, 404
  end

  test "failed GET authenticate_via_magic_link_path by expired token" do
    Aikotoba::Account::MagicLink.create_token!(account: @account, notify: false)
    @account.magic_link_token.update!(expired_at: 1.hour.ago)
    get aikotoba.authenticate_via_magic_link_path(token: @account.magic_link_token.token)
    assert_equal status, 404
  end

  test "failed GET authenticate_via_magic_link_path by nil token" do
    assert_raises(ActionController::UrlGenerationError) do
      get aikotoba.authenticate_via_magic_link_path(token: nil)
    end
  end

  test "with request_back_after_sign_in enabled, magic link sign in redirects back to the page captured at sign_in" do
    Aikotoba.default_scope = {request_back_after_sign_in: true}
    get aikotoba.new_session_path, headers: {"HTTP_REFERER" => "http://www.example.com/sensitives"}
    Aikotoba::Account::MagicLink.create_token!(account: @account, notify: false)
    get aikotoba.authenticate_via_magic_link_path(token: @account.magic_link_token.token)
    assert_redirected_to "/sensitives"
  ensure
    Aikotoba.default_scope = {request_back_after_sign_in: false}
  end

  test "with request_back_after_sign_in enabled, bouncing between sign_in and magic_link pages does not clobber the captured return_to" do
    Aikotoba.default_scope = {request_back_after_sign_in: true}
    get aikotoba.new_session_path, headers: {"HTTP_REFERER" => "http://www.example.com/sensitives"}
    get aikotoba.new_magic_link_path, headers: {"HTTP_REFERER" => "http://www.example.com#{aikotoba.new_session_path}"}
    get aikotoba.new_session_path, headers: {"HTTP_REFERER" => "http://www.example.com#{aikotoba.new_magic_link_path}"}
    Aikotoba::Account::MagicLink.create_token!(account: @account, notify: false)
    get aikotoba.authenticate_via_magic_link_path(token: @account.magic_link_token.token)
    assert_redirected_to "/sensitives"
  ensure
    Aikotoba.default_scope = {request_back_after_sign_in: false}
  end

  test "MagicLinkAuthenticatable path returns 404 when Aikotoba.magic_link_authenticatable is false" do
    Aikotoba.magic_link_authenticatable = false
    get aikotoba.new_magic_link_path
    assert_equal 404, status
    Aikotoba::Account::MagicLink.create_token!(account: @account, notify: false)
    get aikotoba.authenticate_via_magic_link_path(token: @account.magic_link_token.token)
    assert_equal 404, status
    post aikotoba.create_magic_link_path, params: {account: {email: @account.email}}
    assert_equal 404, status
  end
end
