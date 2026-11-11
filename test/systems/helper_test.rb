require "test_helper"

class HelperTest < ActionDispatch::SystemTestCase
  include Aikotoba::Test::AuthenticationHelper::System

  driven_by :rack_test

  def setup
    Aikotoba.config.confirmable = false
    email, @password = ["email@example.com", "password"]
    @account = ::Aikotoba::Account.build_by(attributes: {email: email, password: @password})
    @account.save
  end

  test "sign_in by helper" do
    aikotoba_sign_in(@account, password: @password)
    visit "/sensitives"
    assert_selector "h1", text: "Sensitive Page"
    click_on "Sign out"
    assert_selector ".message", text: "Signed out."
  end

  test "sign_out by helper" do
    aikotoba_sign_in(@account, password: @password)
    visit "/sensitives"
    aikotoba_sign_out
    visit "/sensitives"
    assert_selector "h1", text: "Sign in"
    assert_selector ".message", text: "Oops. You need to Signed up or Signed in."
  end

  test "sign_in by helper enters the code when the default scope requires it" do
    Aikotoba.config.default_scope[:two_factor_authenticatable] = true
    aikotoba_sign_in(@account, password: @password)
    visit "/sensitives"
    assert_selector "h1", text: "Sensitive Page"
  end

  test "sign in through the pages with a code" do
    Aikotoba.config.default_scope[:two_factor_authenticatable] = true
    visit aikotoba.new_session_path
    fill_in "Email", with: @account.email
    fill_in "Password", with: @password
    click_on "Sign in"
    assert_selector "h1", text: "Two-factor authentication"
    assert_selector ".message", text: "One more step is needed to finish signing in."
    assert_text "We sent a verification code to your email address."
    fill_in "Verification code", with: @account.reload.email_otp_code.code
    click_on "Verify"
    assert_selector "h1", text: "Sensitive Page"
  end
end
