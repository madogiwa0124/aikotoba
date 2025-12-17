# frozen_string_literal: true

require "test_helper"

class Aikotoba::AuthenticatableTest < ActionDispatch::IntegrationTest
  def setup
    ActionController::Base.allow_forgery_protection = false
    Aikotoba.confirmable = false
    email, password = ["email@example.com", "password"]
    @account = ::Aikotoba::Account.build_by(attributes: {email: email, password: password})
    @account.save!
  end

  test "success GET new_session_path" do
    get aikotoba.new_session_path
    assert_equal 200, status
    assert_select "h1", I18n.t(".aikotoba.sessions.new")
  end

  test "If GET new_session_path while logged in, it will be redirect to after_sign_in_path" do
    post aikotoba.new_session_path, params: {account: {email: @account.email, password: @account.password}}
    assert_redirected_to Aikotoba.default_scope[:after_sign_in_path]
    get aikotoba.new_session_path
    assert_redirected_to Aikotoba.default_scope[:after_sign_in_path]
  end

  test "success POST new_session_path" do
    post aikotoba.new_session_path, params: {account: {email: @account.email, password: @account.password}}
    assert_redirected_to Aikotoba.default_scope[:after_sign_in_path]
    assert_equal I18n.t(".aikotoba.messages.authentication.success"), flash[:notice]
  end

  test "failed POST new_session_path" do
    post aikotoba.new_session_path, params: {account: {email: @account.email, password: "invalid_password"}}
    assert_equal status, 422
    assert_equal I18n.t(".aikotoba.messages.authentication.failed"), flash[:alert]
  end

  test "success DELETE destroy_session_path" do
    post aikotoba.new_session_path, params: {account: {email: @account.email, password: @account.password}}
    assert cookies[Aikotoba.default_scope[:session_key]].present?
    delete aikotoba.destroy_session_path
    assert cookies[Aikotoba.default_scope[:session_key]].blank?
    assert_redirected_to Aikotoba.default_scope[:after_sign_out_path]
  end

  test "If the unauthenticaticatable after login, cannot access the login required page." do
    Aikotoba.confirmable = true
    @account.update!(confirmed: true)
    post aikotoba.new_session_path, params: {account: {email: @account.email, password: @account.password}}
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
    post aikotoba.new_session_path, params: {account: {email: @account.email, password: @account.password}}
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

  test "If legacy session is set, it is automatically migrated to the new cookie format" do
    Aikotoba.keep_legacy_login_session = true
    # Set legacy session
    session_key = Aikotoba.default_scope[:session_key]
    post "/test/set-legacy-session", params: {key: session_key, value: @account.id}
    assert_response :success

    get Aikotoba.default_scope[:after_sign_in_path]
    assert_response :success

    cookiejar = ActionDispatch::Cookies::CookieJar.build(request, cookies.to_hash)
    aikotoba_session_token = cookiejar.signed[session_key]
    assert aikotoba_session_token.present?

    session_record = @account.sessions.find_by(token: aikotoba_session_token)
    assert session_record.present?
    assert_equal session_record.aikotoba_account_id, @account.id
    Aikotoba.keep_legacy_login_session = false
  end
end
