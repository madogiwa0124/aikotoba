# frozen_string_literal: true

require "test_helper"
require "minitest/autorun"

class Aikotoba::AccountsController::EmailPasswordTest < ActionDispatch::IntegrationTest
  def setup
    Aikotoba.authentication_strategy = :email_password
    ActionController::Base.allow_forgery_protection = false
  end

  test "success GET sign_up_path" do
    get Aikotoba.sign_up_path
    assert_equal 200, status
    assert_select "h1", I18n.t(".aikotoba.accounts.new")
  end

  test "success POST sign_up_path" do
    email, password = ["email@example.com", "password"]
    post Aikotoba.sign_up_path, params: {account: {strategy: :email_password, email: email, password: password}}
    assert_redirected_to Aikotoba.after_sign_up_path
    message = I18n.t(".aikotoba.messages.registration.strategies.email_password.success")
    assert_equal message, flash[:notice]
  end

  test "failed POST sign_up_path" do
    email, password = ["", "password"]
    post Aikotoba.sign_up_path, params: {account: {strategy: :email_password, email: email, password: password}}
    assert_equal I18n.t(".aikotoba.messages.registration.failed"), flash[:alert]
  end
end
