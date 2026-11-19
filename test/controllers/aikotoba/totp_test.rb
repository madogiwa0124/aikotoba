# frozen_string_literal: true

require "test_helper"

# NOTE: A scope offering [:totp, :email_otp]: an account that set up TOTP signs in with its
#       authenticator app, any other with an emailed code, and the set up page is for signed in
#       accounts.
class Aikotoba::TotpTest < ActionDispatch::IntegrationTest
  include Aikotoba::Test::AuthenticationHelper::Request

  def setup
    ActionController::Base.allow_forgery_protection = false
    Aikotoba.config.default_scope[:two_factor_strategies] = %w[totp email_otp]
    @password = "password"
    @account = Aikotoba::Account.create_by!(attributes: {email: "totp_flow@example.com", password: @password})
  end

  def totp
    Aikotoba::Account::TwoFactor::Totp.new(account: @account)
  end

  # NOTE: Confirmed with the previous step's code, so the current one is still unused.
  def set_up_totp!
    credential = totp.enroll!
    assert totp.enable!(ROTP::TOTP.new(credential.secret).at(Time.current - 30))
    credential.reload
  end

  def current_code(credential = @account.reload.totp_credential)
    ROTP::TOTP.new(credential.secret).now
  end

  def sign_in_with_password
    post aikotoba.create_session_path, params: {account: {email: @account.email, password: @password}}
  end

  def assert_signed_in
    get "/sensitives"
    assert_response :ok
  end

  def assert_not_signed_in
    get "/sensitives"
    assert_redirected_to aikotoba.new_session_path
  end

  class SigningIn < Aikotoba::TotpTest
    test "an account that set up TOTP is asked for its app's code, and no email is sent" do
      set_up_totp!
      assert_no_emails { sign_in_with_password }
      assert_redirected_to aikotoba.new_two_factor_path
      follow_redirect!
      assert_select "p", I18n.t(".aikotoba.two_factors.totp.instruction")
      assert_select "input[name='two_factor[code]'][autocomplete='one-time-code']"

      post aikotoba.create_two_factor_path, params: {two_factor: {code: current_code}}
      assert_redirected_to Aikotoba.default_scope[:after_sign_in_path]
      assert_signed_in
    end

    test "an account without TOTP signs in with an emailed code" do
      assert_emails(1) { sign_in_with_password }
      post aikotoba.create_two_factor_path, params: {two_factor: {code: @account.reload.email_otp_code.code}}
      assert_redirected_to Aikotoba.default_scope[:after_sign_in_path]
    end

    test "a wrong TOTP code shows the form again and counts as a failed sign in" do
      set_up_totp!
      sign_in_with_password
      assert_event_reported("aikotoba.totp_sign_in_failed", payload: {account_id: @account.id}) do
        post aikotoba.create_two_factor_path, params: {two_factor: {code: "not a code"}}
      end
      assert_response :unprocessable_entity
      assert_equal I18n.t(".aikotoba.messages.two_factor.failed"), flash[:alert]
      assert_equal 1, @account.reload.failed_attempts
      assert_not_signed_in
    end

    test "a code used once can't sign in again" do
      set_up_totp!
      code = current_code
      sign_in_with_password
      post aikotoba.create_two_factor_path, params: {two_factor: {code: code}}
      delete aikotoba.destroy_session_path

      sign_in_with_password
      post aikotoba.create_two_factor_path, params: {two_factor: {code: code}}
      assert_response :unprocessable_entity
    end

    test "the test helper signs in with the app's code, twice in a row" do
      set_up_totp!
      aikotoba_sign_in(@account, password: @password)
      assert_signed_in
      aikotoba_sign_out
      aikotoba_sign_in(@account, password: @password)
      assert_signed_in
    end

    test "the test helper asks for travel when no code is valid yet, rather than entering one that fails" do
      credential = totp.enroll!
      assert totp.enable!(ROTP::TOTP.new(credential.secret).at(Time.current + 30))
      error = assert_raises(RuntimeError) { aikotoba_sign_in(@account, password: @password) }
      assert_match(/travel 30.seconds/, error.message)
      travel 30.seconds
      aikotoba_sign_in(@account, password: @password)
      assert_signed_in
    end
  end

  class SettingUp < Aikotoba::TotpTest
    def setup
      super
      aikotoba_sign_in(@account, password: @password)
    end

    test "the page needs a signed in account" do
      aikotoba_sign_out
      get aikotoba.two_factor_totp_path
      assert_redirected_to aikotoba.new_session_path
    end

    # NOTE: An app with automatic role switching sends a GET to the reading role, where writes
    #       raise; showing the page creates the pending secret, so it must use the writing role.
    test "the page creates the pending secret even where a GET may not write" do
      ActiveRecord::Base.while_preventing_writes { get aikotoba.two_factor_totp_path }
      assert_response :ok
      assert_not_nil @account.reload.totp_credential
    end

    test "the page shows a QR code and the key, and keeps the same key on reload" do
      get aikotoba.two_factor_totp_path
      assert_response :ok
      assert_select ".aikotoba-totps-qr-code svg"
      secret = @account.reload.totp_credential.secret
      assert_select "code", secret.scan(/.{1,4}/).join(" ")
      assert_not_includes response.body, "<?xml"

      get aikotoba.two_factor_totp_path
      assert_equal secret, @account.reload.totp_credential.secret
    end

    test "a code from the app turns TOTP on" do
      get aikotoba.two_factor_totp_path
      assert_event_reported("aikotoba.totp_enabled") do
        post aikotoba.create_two_factor_totp_path, params: {totp: {code: current_code}}
      end
      assert_redirected_to aikotoba.two_factor_totp_path
      assert_equal I18n.t(".aikotoba.messages.totp.enabled"), flash[:notice]
      assert totp.usable?

      follow_redirect!
      assert_select "p", I18n.t(".aikotoba.totps.enabled")
    end

    test "sending the form again once it is on shows it as set up, not as a wrong code" do
      get aikotoba.two_factor_totp_path
      code = current_code
      post aikotoba.create_two_factor_totp_path, params: {totp: {code: code}}
      post aikotoba.create_two_factor_totp_path, params: {totp: {code: code}}
      assert_redirected_to aikotoba.two_factor_totp_path
      assert_nil flash[:alert]
    end

    test "a wrong code doesn't turn it on" do
      get aikotoba.two_factor_totp_path
      post aikotoba.create_two_factor_totp_path, params: {totp: {code: "not a code"}}
      assert_response :unprocessable_entity
      assert_select ".aikotoba-totps-qr-code svg"
      assert_not totp.usable?
    end

    test "a current code turns it off, a wrong one doesn't and counts as a failed sign in" do
      set_up_totp!
      delete aikotoba.destroy_two_factor_totp_path, params: {totp: {code: "not a code"}}
      assert_response :unprocessable_entity
      assert_select "p", I18n.t(".aikotoba.totps.enabled")
      assert totp.usable?
      assert_equal 1, @account.reload.failed_attempts

      delete aikotoba.destroy_two_factor_totp_path, params: {totp: {code: current_code}}
      assert_redirected_to aikotoba.two_factor_totp_path
      assert_equal I18n.t(".aikotoba.messages.totp.disabled"), flash[:notice]
      assert_not totp.usable?
    end

    test "turning off what isn't on shows the set up page again" do
      delete aikotoba.destroy_two_factor_totp_path, params: {totp: {code: "123456"}}
      assert_response :unprocessable_entity
      assert_select ".aikotoba-totps-qr-code svg"
    end

    test "the page isn't routed in a scope that doesn't offer TOTP" do
      Aikotoba.config.default_scope[:two_factor_strategies] = %w[email_otp]
      get aikotoba.two_factor_totp_path
      assert_response :not_found
    end
  end
end
