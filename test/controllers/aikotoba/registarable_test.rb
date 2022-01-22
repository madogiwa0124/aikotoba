# frozen_string_literal: true

require "test_helper"
require "minitest/autorun"

class Aikotoba::RegisterableTest < ActionDispatch::IntegrationTest
  def setup
    Aikotoba.registerable = true
    ActionController::Base.allow_forgery_protection = false
  end

  def teardown
    Aikotoba.registerable = false
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
    assert_includes messages, "Password is invalid."
    assert_includes messages, "Email can't be blank"
  end

  test "Registerable path to 404 when Aikotoba.registerable is false" do
    Aikotoba.registerable = false
    get aikotoba.new_account_path
    assert_equal 404, status
    post aikotoba.create_account_path, params: {account: {email: "test@example.com", password: "password"}}
    assert_equal 404, status
  end
end
