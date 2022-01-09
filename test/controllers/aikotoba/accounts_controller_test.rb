# frozen_string_literal: true

require "test_helper"
require "minitest/autorun"

class Aikotoba::AccountsControllerTest < ActionDispatch::IntegrationTest
  def setup
    ActionController::Base.allow_forgery_protection = false
  end

  test "success GET sign_up_path" do
    get Aikotoba.sign_up_path
    assert_equal 200, status
    assert_select "h1", I18n.t(".aikotoba.accounts.new")
  end

  test "success POST sign_up_path when valid account attributes" do
    email, password = ["email@example.com", "password"]
    post Aikotoba.sign_up_path, params: {account: {email: email, password: password}}
    assert_redirected_to Aikotoba.after_sign_up_path
    message = I18n.t(".aikotoba.messages.registration.success")
    assert_equal message, flash[:notice]
  end

  test "failed POST sign_up_path when invalid account attributes" do
    email, password = ["", "pass"]
    post Aikotoba.sign_up_path, params: {account: {email: email, password: password}}
    assert_equal I18n.t(".aikotoba.messages.registration.failed"), flash[:alert]
    assert_equal status, 422
    messages = @controller.instance_variable_get(:@account).errors.full_messages
    assert_includes messages, "Password is too short (minimum is 8 characters)"
    assert_includes messages, "Email can't be blank"
  end
end
