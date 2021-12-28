require "test_helper"

class NavigationTest < ActionDispatch::SystemTestCase
  driven_by :rack_test

  test "EmailPassword: sign_up -> sign_in -> sign_out" do
    Aikotoba.enable_confirm = false
    Aikotoba.authentication_strategy = :email_password
    visit Aikotoba.sign_up_path
    fill_in "Email", with: "sample1@example.com"
    fill_in "Password",	with: "password"
    click_on "Sign up"
    assert_selector ".message", text: "Signed up successfully."
    fill_in "Email", with: "sample1@example.com"
    fill_in "Password",	with: "password"
    click_on "Sign in"
    assert_selector ".message", text: "Signed in successfully."
    click_on "Sign out"
  end

  test "(Confirmable) EmailPassword: sign_up -> generate confirm token -> confirm -> sign_in -> sign_out" do
    Aikotoba.authentication_strategy = :email_password
    Aikotoba.enable_confirm = true
    visit Aikotoba.sign_up_path
    fill_in "Email", with: "sample2@example.com"
    fill_in "Password",	with: "password"
    click_on "Sign up"
    assert_selector ".message", text: "Signed up successfully."
    fill_in "Email", with: "sample2@example.com"
    fill_in "Password",	with: "password"
    click_on "Sign in"
    assert_selector ".message", text: "Oops. Signed in failed."
    click_on "Send confirm token"
    fill_in "Email", with: "sample2@example.com"
    click_on "Send confirm token"
    assert_selector ".message", text: "Confirm url has been sent to your email address."
    confirm_email = ActionMailer::Base.deliveries.last
    confirm_path = confirm_email.body.to_s.split(" ")[2] # NOTE: get XXX from "Confirm URL: XXX"
    visit confirm_path
    assert_selector ".message", text: "Confirmed you email successfully."
    click_on "Sign in"
    fill_in "Email", with: "sample2@example.com"
    fill_in "Password",	with: "password"
    click_on "Sign in"
    assert_selector ".message", text: "Signed in successfully."
    click_on "Sign out"
    Aikotoba.enable_confirm = false
  end

  test "(Lockable) EmailPassword: sign_up -> sign_in -> locked -> generate unlock token -> unlock -> sign_in -> sign_out" do
    Aikotoba.authentication_strategy = :email_password
    Aikotoba.enable_lock = true
    visit Aikotoba.sign_up_path
    fill_in "Email", with: "sample3@example.com"
    fill_in "Password",	with: "password"
    click_on "Sign up"
    assert_selector ".message", text: "Signed up successfully."
    11.times do
      fill_in "Email", with: "sample3@example.com"
      fill_in "Password",	with: "wrong password"
      click_on "Sign in"
    end
    fill_in "Email", with: "sample3@example.com"
    fill_in "Password",	with: "password"
    click_on "Sign in"
    assert_selector ".message", text: "Oops. Signed in failed."
    click_on "Send unlock token"
    fill_in "Email", with: "sample3@example.com"
    click_on "Send unlock token"
    assert_selector ".message", text: "Unlock url has been sent to your email address."
    unlock_email = ActionMailer::Base.deliveries.last
    unlock_path = unlock_email.body.to_s.split(" ")[2] # NOTE: get XXX from "Unlock URL: XXX"
    visit unlock_path
    assert_selector ".message", text: "Unlocked you account successfully."
    click_on "Sign in"
    fill_in "Email", with: "sample3@example.com"
    fill_in "Password",	with: "password"
    click_on "Sign in"
    assert_selector ".message", text: "Signed in successfully."
    click_on "Sign out"
    Aikotoba.enable_lock = false
  end
end
