# frozen_string_literal: true

require "test_helper"

# NOTE: Checks the README's own sign up controller example (test/dummy's SignUpsController),
#       the replacement for overriding AccountsController's removed hooks.
class CustomSignUpTest < ActionDispatch::IntegrationTest
  def setup
    ActionController::Base.allow_forgery_protection = false
  end

  test "creates the account and its User in one transaction, and reports account_registered" do
    assert_event_reported("aikotoba.account_registered") do
      post "/custom_sign_up", params: {account: {email: "email@example.com", password: "password", nickname: "foo"}}
    end

    assert_response :created
    account = Aikotoba::Account.find_by!(email: "email@example.com")
    assert_equal "foo", account.authenticate_target.nickname
  end

  test "rolls the User back when the account is invalid, and reports nothing" do
    assert_no_difference -> { User.count } do
      assert_no_event_reported("aikotoba.account_registered") do
        post "/custom_sign_up", params: {account: {email: "email@example.com", password: "short", nickname: "foo"}}
      end
    end

    assert_response :unprocessable_entity
    assert_not Aikotoba::Account.exists?(email: "email@example.com")
  end
end
