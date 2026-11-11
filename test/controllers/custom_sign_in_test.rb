# frozen_string_literal: true

require "test_helper"

# NOTE: Checks the README's own sign in controller example (test/dummy's SignInsController):
#       aikotoba_begin_sign_in signs in, or sends a code when the scope requires one.
class CustomSignInTest < ActionDispatch::IntegrationTest
  def setup
    ActionController::Base.allow_forgery_protection = false
    @account = Aikotoba::Account.create_by!(attributes: {email: "custom_sign_in@example.com", password: "password"})
  end

  test "signs in right away when the scope doesn't require a code" do
    assert_event_reported("aikotoba.sign_in") do
      post "/custom_sign_in", params: {email: @account.email, password: "password"}
    end
    assert_redirected_to "/sensitives"
    assert_nil @account.reload.email_otp_code
  end

  test "sends a code and leaves the account signed out when the scope requires one" do
    Aikotoba.config.default_scope[:two_factor_authenticatable] = true
    @account.update!(failed_attempts: 2)
    assert_emails 1 do
      assert_no_event_reported("aikotoba.sign_in") do
        post "/custom_sign_in", params: {email: @account.email, password: "password"}
      end
    end
    assert_redirected_to aikotoba.new_two_factor_path
    assert_equal 2, @account.reload.failed_attempts

    post aikotoba.create_two_factor_path, params: {two_factor: {response: @account.email_otp_code.code}}
    assert_redirected_to Aikotoba.default_scope[:after_sign_in_path]
    get "/sensitives"
    assert_response :ok
  end

  test "a wrong password signs nothing in" do
    post "/custom_sign_in", params: {email: @account.email, password: "wrong"}
    assert_response :unprocessable_entity
  end
end
