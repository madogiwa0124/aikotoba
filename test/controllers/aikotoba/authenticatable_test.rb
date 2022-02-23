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
    assert_redirected_to Aikotoba.after_sign_in_path
    get aikotoba.new_session_path
    assert_redirected_to Aikotoba.after_sign_in_path
  end

  test "success POST new_session_path" do
    post aikotoba.new_session_path, params: {account: {email: @account.email, password: @account.password}}
    assert_redirected_to Aikotoba.after_sign_in_path
    assert_equal I18n.t(".aikotoba.messages.authentication.success"), flash[:notice]
  end

  test "failed POST new_session_path" do
    post aikotoba.new_session_path, params: {account: {email: @account.email, password: "invalid_password"}}
    assert_equal status, 422
    assert_equal I18n.t(".aikotoba.messages.authentication.failed"), flash[:alert]
  end

  test "success DELETE destroy_session_path" do
    post aikotoba.new_session_path, params: {account: {email: @account.email, password: @account.password}}
    assert_not_nil session[Aikotoba.session_key]
    delete aikotoba.destroy_session_path
    assert_nil session[Aikotoba.session_key]
    assert_redirected_to Aikotoba.after_sign_out_path
  end

  test "If the unauthenticaticatable after login, cannot access the login required page." do
    Aikotoba.confirmable = true
    @account.update!(confirmed: true)
    post aikotoba.new_session_path, params: {account: {email: @account.email, password: @account.password}}
    assert_redirected_to Aikotoba.after_sign_in_path
    assert_equal I18n.t(".aikotoba.messages.authentication.success"), flash[:notice]
    @account.update!(confirmed: false)
    get Aikotoba.after_sign_in_path
    assert_redirected_to aikotoba.new_session_path
    @account.update!(confirmed: true)
    get Aikotoba.after_sign_in_path
    assert_redirected_to aikotoba.new_session_path
    Aikotoba.confirmable = false
  end
end
