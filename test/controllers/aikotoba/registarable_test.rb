# frozen_string_literal: true

require "test_helper"
require "minitest/autorun"

class Aikotoba::RegisterableTest < ActionDispatch::IntegrationTest
  def setup
    Aikotoba.config.registerable = true
    ActionController::Base.allow_forgery_protection = false
  end

  test "success GET new_account_path" do
    get aikotoba.new_account_path
    assert_equal 200, status
    assert_select "h1", I18n.t(".aikotoba.accounts.new")
  end

  test "success POST create_account_path when valid account attributes" do
    email, password = ["email@example.com", "password"]
    post aikotoba.create_account_path, params: {account: {email: email, password: password}}
    assert_redirected_to aikotoba.new_session_path
    message = I18n.t(".aikotoba.messages.registration.success")
    assert_equal message, flash[:notice]
  end

  test "failed POST create_account_path when invalid account attributes" do
    email, password = ["", "pass"]
    post aikotoba.create_account_path, params: {account: {email: email, password: password}}
    assert_equal I18n.t(".aikotoba.messages.registration.failed"), flash[:alert]
    assert_equal status, 422
    messages = @controller.instance_variable_get(:@account).errors.full_messages
    assert_includes messages, "Password is too short (minimum is 8 characters)"
    assert_includes messages, "Email can't be blank"
  end

  test "failed POST create_account_path when password param is omitted entirely" do
    assert_no_difference "Aikotoba::Account.count" do
      post aikotoba.create_account_path, params: {account: {email: "no-password@example.com"}}
    end
    assert_equal status, 422
    messages = @controller.instance_variable_get(:@account).errors.full_messages
    assert_includes messages, "Password can't be blank"
  end

  test "Registerable path to 404 in a scope with authenticate_for, even when Aikotoba.registerable is true" do
    get "/admin/sign_up"
    assert_equal 404, status
    assert_no_difference "Aikotoba::Account.count" do
      post "/admin/sign_up", params: {account: {email: "admin_signup@example.com", password: "password"}}
    end
    assert_equal 404, status
  end

  test "Registerable path to 404 when Aikotoba.registerable is false" do
    Aikotoba.config.registerable = false
    get aikotoba.new_account_path
    assert_equal 404, status
    post aikotoba.create_account_path, params: {account: {email: "test@example.com", password: "password"}}
    assert_equal 404, status
    Aikotoba.config.registerable = true
  end
end
