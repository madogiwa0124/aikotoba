# frozen_string_literal: true

require "test_helper"

class Aikotoba::AuthenticatableTest < ActionDispatch::IntegrationTest
  def setup
    ActionController::Base.allow_forgery_protection = false
    Aikotoba.confirmable = false
    @password = "password"
    @account = ::Aikotoba::Account.build_by(attributes: {email: "email@example.com", password: @password})
    @account.save!
  end

  test "success GET new_session_path" do
    get aikotoba.new_session_path
    assert_equal 200, status
    assert_select "h1", I18n.t(".aikotoba.sessions.new")
  end

  test "If GET new_session_path while logged in, it will be redirect to after_sign_in_path" do
    post aikotoba.new_session_path, params: {account: {email: @account.email, password: @password}}
    assert_redirected_to Aikotoba.default_scope[:after_sign_in_path]
    get aikotoba.new_session_path
    assert_redirected_to Aikotoba.default_scope[:after_sign_in_path]
  end

  test "success POST new_session_path" do
    post aikotoba.new_session_path, params: {account: {email: @account.email, password: @password}}
    assert_redirected_to Aikotoba.default_scope[:after_sign_in_path]
    assert_equal I18n.t(".aikotoba.messages.authentication.success"), flash[:notice]
  end

  test "failed POST new_session_path" do
    post aikotoba.new_session_path, params: {account: {email: @account.email, password: "invalid_password"}}
    assert_equal status, 422
    assert_equal I18n.t(".aikotoba.messages.authentication.failed"), flash[:alert]
  end

  test "success DELETE destroy_session_path" do
    post aikotoba.new_session_path, params: {account: {email: @account.email, password: @password}}
    assert cookies[Aikotoba.default_scope[:session_key]].present?
    delete aikotoba.destroy_session_path
    assert cookies[Aikotoba.default_scope[:session_key]].blank?
    assert_redirected_to Aikotoba.default_scope[:after_sign_out_path]
  end

  test "If the unauthenticaticatable after login, cannot access the login required page." do
    Aikotoba.confirmable = true
    @account.update!(confirmed: true)
    post aikotoba.new_session_path, params: {account: {email: @account.email, password: @password}}
    assert_redirected_to Aikotoba.default_scope[:after_sign_in_path]
    assert_equal I18n.t(".aikotoba.messages.authentication.success"), flash[:notice]
    @account.update!(confirmed: false)
    get Aikotoba.default_scope[:after_sign_in_path]
    assert_redirected_to aikotoba.new_session_path
    # Note: After being considered unauthenticatable once and redirected to the login page,
    # the sign-out process is performed, so if you access the login page again, you will be redirected again.
    @account.update!(confirmed: true)
    get Aikotoba.default_scope[:after_sign_in_path]
    assert_redirected_to aikotoba.new_session_path
    Aikotoba.confirmable = false
  end

  test "after being sent to sign in from a protected page, signing in redirects back to that page" do
    # NOTE: The Referer is the page that linked to the protected page, exactly as a
    # real browser keeps it across the redirect -- it must not be what's restored.
    get "/sensitives?from=protected", headers: {"HTTP_REFERER" => "http://www.example.com/linked_from"}
    assert_redirected_to aikotoba.new_session_path
    follow_redirect!
    assert_equal 200, status
    post aikotoba.new_session_path, params: {account: {email: @account.email, password: @password}}
    assert_redirected_to "/sensitives?from=protected"
  end

  test "signing in without being sent from a protected page falls back to after_sign_in_path" do
    get aikotoba.new_session_path, headers: {"HTTP_REFERER" => "http://www.example.com/sensitives?from=referer"}
    post aikotoba.new_session_path, params: {account: {email: @account.email, password: @password}}
    assert_redirected_to Aikotoba.default_scope[:after_sign_in_path]
  end

  test "the stored return_to path is used only once" do
    get "/sensitives?from=protected"
    post aikotoba.new_session_path, params: {account: {email: @account.email, password: @password}}
    assert_redirected_to "/sensitives?from=protected"
    delete aikotoba.destroy_session_path
    post aikotoba.new_session_path, params: {account: {email: @account.email, password: @password}}
    assert_redirected_to Aikotoba.default_scope[:after_sign_in_path]
  end

  test "a protected request that can't be replayed as a page visit is not stored as the return_to path" do
    get "/sensitives.json?from=json"
    get "/sensitives?from=xhr", xhr: true
    post aikotoba.new_session_path, params: {account: {email: @account.email, password: @password}}
    assert_redirected_to Aikotoba.default_scope[:after_sign_in_path]
  end

  test "a protocol-relative path is not stored as the return_to path" do
    controller = ApplicationController.new
    ["//evil.example.com/phish", "/\\evil.example.com/phish"].each do |path|
      controller.request = ActionDispatch::TestRequest.create("REQUEST_METHOD" => "GET", "HTTP_ACCEPT" => "text/html")
      assert_not controller.send(:aikotoba_storable_return_to_path?, path), path
    end
    assert controller.send(:aikotoba_storable_return_to_path?, "/sensitives?from=protected")
  end

  test "the return_to path is stored per scope" do
    admin_email, admin_password = ["admin@example.com", "admin_password"]
    admin_account = ::Aikotoba::Account.build_by(attributes: {email: admin_email, password: admin_password})
    admin_account.authenticate_target = Admin.new(nickname: "admin_foo")
    admin_account.save!
    get "/sensitives?from=default"
    get "/admin/sensitives?from=admin"
    assert_redirected_to aikotoba.admin_new_session_path
    post aikotoba.admin_new_session_path, params: {account: {email: admin_email, password: admin_password}}
    assert_redirected_to "/admin/sensitives?from=admin"
    post aikotoba.new_session_path, params: {account: {email: @account.email, password: @password}}
    assert_redirected_to "/sensitives?from=default"
  end

  test "success admin scope authentication" do
    admin_email, admin_password = ["admin@example.com", "admin_password"]
    admin_account = ::Aikotoba::Account.build_by(attributes: {email: admin_email, password: admin_password})
    admin_account.authenticate_target = Admin.new(nickname: "admin_foo")
    admin_account.save!
    post aikotoba.admin_new_session_path, params: {account: {email: admin_email, password: admin_password}}
    assert_redirected_to Aikotoba.scopes[:admin][:after_sign_in_path]
    assert_equal I18n.t(".aikotoba.messages.authentication.success"), flash[:notice]
  end

  test "failed admin scope authentication by wrong target type" do
    user_email, user_password = ["user@example.com", "user_password"]
    user_account = ::Aikotoba::Account.build_by(attributes: {email: user_email, password: user_password})
    user_account.authenticate_target = User.new(nickname: "user_foo")
    user_account.save!
    post aikotoba.admin_new_session_path, params: {account: {email: user_email, password: user_password}}
    assert_equal status, 422
    assert_equal I18n.t(".aikotoba.messages.authentication.failed"), flash[:alert]
  end

  test "If remove session record directly, the session is terminated on the next request." do
    post aikotoba.new_session_path, params: {account: {email: @account.email, password: @password}}
    assert_redirected_to Aikotoba.default_scope[:after_sign_in_path]
    # NOTE: Rebuild the cookies jar to read signed cookies.
    cookiejar = ActionDispatch::Cookies::CookieJar.build(request, cookies.to_hash)
    aikotoba_session_token = cookiejar.signed[Aikotoba.default_scope[:session_key]]
    session_record = @account.sessions.find_by(token: aikotoba_session_token)
    assert session_record.present?
    # Directly delete the session record to simulate external session invalidation.
    session_record.destroy!
    get Aikotoba.default_scope[:after_sign_in_path]
    assert_redirected_to aikotoba.new_session_path
  end
end
