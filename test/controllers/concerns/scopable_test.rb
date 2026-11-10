# frozen_string_literal: true

require "test_helper"

class Aikotoba::ScopableTest < ActionDispatch::IntegrationTest
  def setup
    ActionController::Base.allow_forgery_protection = false
    Aikotoba.config.registerable = true
    Aikotoba.config.confirmable = false
    @password = "password"
    @account = ::Aikotoba::Account.build_by(attributes: {email: "scope@example.com", password: @password})
    @account.save!
    @admin_account = ::Aikotoba::Account.build_by(attributes: {email: "admin_scope@example.com", password: @password})
    admin = Admin.new(nickname: "admin_foo")
    @admin_account.authenticate_target = admin
    admin.save!
    @admin_account.save!
  end

  test "default scope: path helpers resolved by aikotoba_scoped_path in views" do
    get aikotoba.new_session_path
    assert_response :success

    # form action points to default create_session path
    assert_select "form[action=?]", "/sign_in"

    # registerable link should point to default new_account path
    assert_select "a[href=?]", "/sign_up", I18n.t(".aikotoba.accounts.new")
  end

  test "admin scope: path helpers resolved by aikotoba_scoped_path in views" do
    get aikotoba.admin_new_session_path
    assert_response :success

    # form action points to admin create_session path
    assert_select "form[action=?]", "/admin/sign_in"

    # admin scope sets authenticate_for, so it offers no sign-up link even with registerable on
    assert_select "a", text: I18n.t(".aikotoba.accounts.new"), count: 0
  end

  test "default scope: after_sign_in_path and session key are from default scope" do
    post aikotoba.new_session_path, params: {account: {email: @account.email, password: @password}}
    assert_redirected_to "/sensitives"
    follow_redirect!
    assert_response :success
    assert cookies[Aikotoba.scopes[:default][:session_key]].present?
  end

  test "admin scope: after_sign_in_path and session key are from admin scope" do
    post aikotoba.admin_create_session_path, params: {account: {email: @admin_account.email, password: @password}}
    assert_redirected_to "/admin/sensitives"
    # Do not follow the redirect to avoid hitting admin-only page
    assert cookies[Aikotoba.scopes[:admin][:session_key]].present?
  end
end

# root_path is relative to where the engine is mounted, so scopes keep working when it is
# mounted somewhere other than "/".
class Aikotoba::ScopableMountedUnderSubpathTest < ActionDispatch::IntegrationTest
  def setup
    ActionController::Base.allow_forgery_protection = false
    Rails.application.routes.draw do
      mount Aikotoba::Engine => "/auth"
      get "/sensitives", to: "sensitives#index"
      get "/admin/sensitives", to: "admin/sensitives#index"
      get "/auth/admin/sensitives", to: "admin/sensitives#index"
    end
    @password = "password"
    @account = Aikotoba::Account.create_by!(attributes: {email: "mounted@example.com", password: @password})
    @admin_account = Aikotoba::Account.create_by!(attributes: {email: "mounted_admin@example.com", password: @password, authenticate_target: Admin.create!(nickname: "mounted")})
  end

  def teardown
    Rails.application.reload_routes!
  end

  test "an engine page under the mount point resolves the scope of its root_path" do
    get "/auth/admin/sign_in"
    assert_response :success
    assert_select "form[action=?]", "/auth/admin/sign_in"
  end

  test "the admin scope does not sign in an account outside its authenticate_for" do
    post "/auth/admin/sign_in", params: {account: {email: @account.email, password: @password}}
    assert_response :unprocessable_entity
    assert_nil cookies[Aikotoba.scopes[:default][:session_key]].presence
  end

  test "the admin scope signs in its own account with its own session key" do
    post "/auth/admin/sign_in", params: {account: {email: @admin_account.email, password: @password}}
    assert_redirected_to "/admin/sensitives"
    assert cookies[Aikotoba.scopes[:admin][:session_key]].present?
    assert_nil cookies[Aikotoba.scopes[:default][:session_key]].presence
  end

  test "a host app page under the mount point resolves the scope of its root_path" do
    post "/auth/admin/sign_in", params: {account: {email: @admin_account.email, password: @password}}
    get "/auth/admin/sensitives"
    assert_response :success
  end

  test "a host app page outside the mount point is in the default scope" do
    post "/auth/admin/sign_in", params: {account: {email: @admin_account.email, password: @password}}
    get "/admin/sensitives"
    assert_redirected_to "/auth/sign_in"
  end

  test "a host app page at the mount point itself is in the default scope" do
    Rails.application.routes.draw do
      mount Aikotoba::Engine => "/auth"
      get "/auth", to: "admin/sensitives#index"
    end
    post "/auth/admin/sign_in", params: {account: {email: @admin_account.email, password: @password}}
    get "/auth"
    assert_redirected_to "/auth/sign_in"
  end

  test "a host app page under the mount point resolves its scope when the app is served under a SCRIPT_NAME" do
    headers = {"SCRIPT_NAME" => "/app"}
    post "/auth/admin/sign_in", params: {account: {email: @admin_account.email, password: @password}}, headers: headers
    get "/auth/admin/sensitives", headers: headers
    assert_response :success
  end

  test "a host app page under the mount point resolves its scope with relative_url_root set" do
    route_config = Rails.application.routes.instance_variable_get(:@config)
    original = route_config.relative_url_root
    route_config.relative_url_root = "/app"
    headers = {"SCRIPT_NAME" => "/app"}
    post "/auth/admin/sign_in", params: {account: {email: @admin_account.email, password: @password}}, headers: headers
    get "/auth/admin/sensitives", headers: headers
    assert_response :success
  ensure
    route_config.relative_url_root = original
  end

  test "a host app route to a subclass of an Aikotoba controller is matched relative to the app" do
    Rails.application.routes.draw do
      mount Aikotoba::Engine => "/auth"
      get "/sensitives", to: "sensitives#index"
      post "/admin/login", to: "host_sessions#create"
    end
    # NOTE: /admin/login is outside the mount point, so it is in the default scope, which
    #       signs in any account. Read as engine-relative, it would be in the admin scope.
    post "/admin/login", params: {account: {email: @account.email, password: @password}}
    assert_redirected_to "/sensitives"
    assert cookies[Aikotoba.scopes[:default][:session_key]].present?
  end
end

class HostSessionsController < Aikotoba::SessionsController
end
