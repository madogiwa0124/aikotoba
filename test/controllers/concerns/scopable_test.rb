# frozen_string_literal: true

require "test_helper"

class Aikotoba::ScopableTest < ActionDispatch::IntegrationTest
  def setup
    ActionController::Base.allow_forgery_protection = false
    Aikotoba.registerable = true
    Aikotoba.confirmable = false
    email, password = ["scope@example.com", "password"]
    @account = ::Aikotoba::Account.build_by(attributes: {email: email, password: password})
    @account.save!
    @admin_account = ::Aikotoba::Account.build_by(attributes: {email: "admin_scope@example.com", password: "password"})
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

    # registerable link should point to admin new_account path
    assert_select "a[href=?]", "/admin/sign_up", I18n.t(".aikotoba.accounts.new")
  end

  test "default scope: after_sign_in_path and session key are from default scope" do
    post aikotoba.new_session_path, params: {account: {email: @account.email, password: @account.password}}
    assert_redirected_to "/sensitives"
    follow_redirect!
    assert_response :success
    assert cookies[Aikotoba.scopes[:default][:session_key]].present?
  end

  test "admin scope: after_sign_in_path and session key are from admin scope" do
    post aikotoba.admin_create_session_path, params: {account: {email: @admin_account.email, password: @admin_account.password}}
    assert_redirected_to "/admin/sensitives"
    # Do not follow the redirect to avoid hitting admin-only page
    assert cookies[Aikotoba.scopes[:admin][:session_key]].present?
  end
end
