require "test_helper"

class NavigationTest < ActionDispatch::SystemTestCase
  driven_by :rack_test

  test "create Aikotoba::Account -> sign_in -> sign_out" do
    Aikotoba::Account.create!(email: "sample1@example.com", password: "password")
    visit Aikotoba.sign_in_path
    fill_in "Email", with: "sample1@example.com"
    fill_in "Password",	with: "password"
    click_on "Sign in"
    assert_selector ".message", text: "Signed in successfully."
    click_on "Sign out"
  end

  test "(Registerable) sign_up -> sign_in -> sign_out" do
    Aikotoba.enable_register = true
    visit Aikotoba.sign_up_path
    fill_in "Email", with: "sample2@example.com"
    fill_in "Password",	with: "password"
    click_on "Sign up"
    assert_selector ".message", text: "Signed up successfully."
    fill_in "Email", with: "sample2@example.com"
    fill_in "Password",	with: "password"
    click_on "Sign in"
    assert_selector ".message", text: "Signed in successfully."
    click_on "Sign out"
    Aikotoba.enable_register = false
  end

  test "(Confirmable) sign_up -> generate confirm token -> confirm -> sign_in -> sign_out" do
    Aikotoba.enable_confirm = true
    Aikotoba::Account.create!(email: "sample3@example.com", password: "password")
    visit Aikotoba.sign_in_path
    fill_in "Email", with: "sample3@example.com"
    fill_in "Password",	with: "password"
    click_on "Sign in"
    assert_selector ".message", text: "Oops. Signed in failed."
    click_on "Send confirm token"
    fill_in "Email", with: "sample3@example.com"
    click_on "Send confirm token"
    assert_selector ".message", text: "Confirm url has been sent to your email address."
    confirm_email = ActionMailer::Base.deliveries.last
    confirm_path = confirm_email.body.to_s.split(" ")[2] # NOTE: get XXX from "Confirm URL: XXX"
    visit confirm_path
    assert_selector ".message", text: "Confirmed you email successfully."
    click_on "Sign in"
    fill_in "Email", with: "sample3@example.com"
    fill_in "Password",	with: "password"
    click_on "Sign in"
    assert_selector ".message", text: "Signed in successfully."
    click_on "Sign out"
    Aikotoba.enable_confirm = false
  end

  test "(Lockable) sign_up -> sign_in -> locked -> generate unlock token -> unlock -> sign_in -> sign_out" do
    Aikotoba.enable_lock = true
    Aikotoba::Account.create!(email: "sample4@example.com", password: "password")
    visit Aikotoba.sign_in_path
    11.times do
      fill_in "Email", with: "sample4@example.com"
      fill_in "Password",	with: "wrong password"
      click_on "Sign in"
    end
    fill_in "Email", with: "sample4@example.com"
    fill_in "Password",	with: "password"
    click_on "Sign in"
    assert_selector ".message", text: "Oops. Signed in failed."
    click_on "Send unlock token"
    fill_in "Email", with: "sample4@example.com"
    click_on "Send unlock token"
    assert_selector ".message", text: "Unlock url has been sent to your email address."
    unlock_email = ActionMailer::Base.deliveries.last
    unlock_path = unlock_email.body.to_s.split(" ")[2] # NOTE: get XXX from "Unlock URL: XXX"
    visit unlock_path
    assert_selector ".message", text: "Unlocked you account successfully."
    click_on "Sign in"
    fill_in "Email", with: "sample4@example.com"
    fill_in "Password",	with: "password"
    click_on "Sign in"
    assert_selector ".message", text: "Signed in successfully."
    click_on "Sign out"
    Aikotoba.enable_lock = false
  end

  test "(Recoverable) sign_up -> sign_in -> generate recover token -> password reset -> sign_in -> sign_out" do
    Aikotoba.enable_recover = true
    Aikotoba::Account.create!(email: "sample5@example.com", password: "password")
    visit Aikotoba.sign_in_path
    click_on "Send password reset token"
    fill_in "Email", with: "sample5@example.com"
    click_on "Send password reset token"
    assert_selector ".message", text: "Password reset url has been sent to your email address."
    recover_email = ActionMailer::Base.deliveries.last
    recover_path = recover_email.body.to_s.split(" ")[3] # NOTE: get XXX from "Password reset URL: XXX"
    visit recover_path
    fill_in "Password",	with: "updated_password"
    click_on "Password reset"
    assert_selector ".message", text: "Password reset you account successfully."
    fill_in "Email", with: "sample5@example.com"
    fill_in "Password",	with: "updated_password"
    click_on "Sign in"
    assert_selector ".message", text: "Signed in successfully."
    click_on "Sign out"
    Aikotoba.enable_recover = false
  end

  test "(ALL) sign_up -> confirm -> sigin_in -> lock -> unlcok -> sigin_in -> recover -> sign_in -> sign_out" do
    Aikotoba.enable_register = true
    Aikotoba.enable_confirm = true
    Aikotoba.enable_recover = true
    Aikotoba.enable_lock = true
    visit Aikotoba.sign_up_path
    fill_in "Email", with: "sample6@example.com"
    fill_in "Password",	with: "password"
    click_on "Sign up"
    assert_selector ".message", text: "Signed up successfully."
    # Confirmable
    confirm_email = ActionMailer::Base.deliveries.last
    confirm_path = confirm_email.body.to_s.split(" ")[2] # NOTE: get XXX from "Confirm URL: XXX"
    visit confirm_path
    assert_selector ".message", text: "Confirmed you email successfully."
    click_on "Sign in"
    fill_in "Email", with: "sample6@example.com"
    fill_in "Password",	with: "password"
    click_on "Sign in"
    assert_selector ".message", text: "Signed in successfully."
    click_on "Sign out"
    # Lockable
    11.times do
      fill_in "Email", with: "sample6@example.com"
      fill_in "Password",	with: "wrong password"
      click_on "Sign in"
    end
    unlock_email = ActionMailer::Base.deliveries.last
    unlock_path = unlock_email.body.to_s.split(" ")[2] # NOTE: get XXX from "Unlock URL: XXX"
    visit unlock_path
    assert_selector ".message", text: "Unlocked you account successfully."
    fill_in "Email", with: "sample6@example.com"
    fill_in "Password",	with: "password"
    click_on "Sign in"
    assert_selector ".message", text: "Signed in successfully."
    click_on "Sign out"
    # Recoverable
    click_on "Send password reset token"
    fill_in "Email", with: "sample6@example.com"
    click_on "Send password reset token"
    assert_selector ".message", text: "Password reset url has been sent to your email address."
    recover_email = ActionMailer::Base.deliveries.last
    recover_path = recover_email.body.to_s.split(" ")[3] # NOTE: get XXX from "Password reset URL: XXX"
    visit recover_path
    fill_in "Password",	with: "updated_password"
    click_on "Password reset"
    assert_selector ".message", text: "Password reset you account successfully."
    fill_in "Email", with: "sample6@example.com"
    fill_in "Password",	with: "updated_password"
    click_on "Sign in"
    assert_selector ".message", text: "Signed in successfully."
    click_on "Sign out"
    Aikotoba.enable_register = false
    Aikotoba.enable_confirm = false
    Aikotoba.enable_recover = false
    Aikotoba.enable_lock = false
  end
end
