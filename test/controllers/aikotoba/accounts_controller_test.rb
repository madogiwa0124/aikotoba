# frozen_string_literal: true

require "test_helper"
require "minitest/autorun"

class Aikotoba::AccountsControllerTest < ActionDispatch::IntegrationTest
  def setup
    Aikotoba.authentication_strategy = :password_only
    ActionController::Base.allow_forgery_protection = false
  end

  test "success GET sign_up_path" do
    get Aikotoba.sign_up_path
    assert_equal 200, status
    assert_select "h1", I18n.t(".aikotoba.accounts.new")
  end

  test "success POST sign_up_path" do
    post Aikotoba.sign_up_path, params: {account: {strategy: :password_only}}
    account = @controller.instance_variable_get("@account")
    assert_redirected_to Aikotoba.after_sign_up_path
    message = I18n.t(".aikotoba.messages.registration.success") + I18n.t(".aikotoba.messages.registration.show_password", password: account.password)
    assert_equal message, flash[:notice]
  end

  test "failed POST sign_up_path" do
    Aikotoba::Account::Strategy::PasswordOnly.stub(:build_account_by, Aikotoba::Account.new) do
      post Aikotoba.sign_up_path, params: {account: {strategy: :password_only}}
      assert_equal I18n.t(".aikotoba.messages.registration.failed"), flash[:alert]
    end
  end
end
