require "test_helper"

class HelperTest < ActionDispatch::SystemTestCase
  include Aikotoba::Test::AuthenticationHelper::System
  driven_by :rack_test

  def setup
    Aikotoba.authentication_strategy = :password_only
  end

  test "sign_in by helper" do
    user = ::Aikotoba::Account.build_account_by({"strategy" => :password_only})
    user.save
    aikotoba_sign_in(user)
    visit "/sensitives"
    assert_selector "h1", text: "Sensitive Page"
    click_on "Sign out"
    assert_selector ".message", text: "Signed out."
  end

  test "sign_out by helper" do
    user = ::Aikotoba::Account.build_account_by({"strategy" => :password_only})
    user.save
    aikotoba_sign_in(user)
    visit "/sensitives"
    aikotoba_sign_out
    visit "/sensitives"
    assert_selector "h1", text: "Sign in"
    assert_selector ".message", text: "Oops. You need to Signed up or Signed in."
  end
end
