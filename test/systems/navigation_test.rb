require "test_helper"

class NavigationTest < ActionDispatch::SystemTestCase
  include ActionMailer::TestHelper

  driven_by :rack_test

  # Default namespace tests
  test "[default] create Aikotoba::Account -> sign_in -> sign_out" do
    Aikotoba::Account.create_by!(attributes: {email: "default1@example.com", password: "password"})
    visit "/sign_in"
    fill_in "Email", with: "default1@example.com"
    fill_in "Password", with: "password"
    click_on "Sign in"
    assert_selector ".message", text: "Signed in successfully."
    click_on "Sign out"
    assert_equal current_path, "/sign_in"
  end

  test "[default] visit protected page -> redirected to sign_in -> sign_in -> back to protected page" do
    Aikotoba::Account.create_by!(attributes: {email: "default7@example.com", password: "password"})
    visit "/sensitives?from=protected"
    assert_current_path "/sign_in"
    fill_in "Email", with: "default7@example.com"
    fill_in "Password", with: "password"
    click_on "Sign in"
    assert_selector ".message", text: "Signed in successfully."
    assert_current_path "/sensitives?from=protected"
    click_on "Sign out"
  end

  test "[default] (Registerable) sign_up -> sign_in -> sign_out" do
    Aikotoba.config.registerable = true
    visit "/sign_up"
    fill_in "Email", with: "default2@example.com"
    fill_in "Password", with: "password"
    click_on "Sign up"
    assert_selector ".message", text: "Signed up successfully."
    fill_in "Email", with: "default2@example.com"
    fill_in "Password", with: "password"
    click_on "Sign in"
    assert_selector ".message", text: "Signed in successfully."
    click_on "Sign out"
  end

  test "[default] (Confirmable) sign_up -> generate confirm token -> confirm -> sign_in -> sign_out" do
    Aikotoba.config.confirmable = true
    Aikotoba::Account.create_by!(attributes: {email: "default3@example.com", password: "password"})
    visit "/sign_in"
    fill_in "Email", with: "default3@example.com"
    fill_in "Password", with: "password"
    click_on "Sign in"
    assert_selector ".message", text: "Oops. Signed in failed."
    click_on "Send confirm token"
    assert_equal current_path, "/confirm"
    fill_in "Email", with: "default3@example.com"
    assert_emails 1 do
      click_on "Send confirm token"
    end
    assert_selector ".message", text: "Confirm url has been sent to your email address (if user with that email address exists)."
    confirm_email = ActionMailer::Base.deliveries.last
    confirm_path = confirm_email.body.to_s.split("\n")[0].split(" ")[2] # NOTE: get XXX from "Confirm URL: XXX"
    visit confirm_path
    assert_selector ".message", text: "Confirmed you email successfully."
    click_on "Sign in"
    fill_in "Email", with: "default3@example.com"
    fill_in "Password", with: "password"
    click_on "Sign in"
    assert_selector ".message", text: "Signed in successfully."
    click_on "Sign out"
  end

  test "[default] (Lockable) sign_up -> sign_in -> locked -> generate unlock token -> unlock -> sign_in -> sign_out" do
    Aikotoba.config.lockable = true
    Aikotoba::Account.create_by!(attributes: {email: "default4@example.com", password: "password"})
    visit "/sign_in"
    11.times do
      fill_in "Email", with: "default4@example.com"
      fill_in "Password", with: "wrong password"
      click_on "Sign in"
    end
    fill_in "Email", with: "default4@example.com"
    fill_in "Password", with: "password"
    click_on "Sign in"
    assert_selector ".message", text: "Oops. Signed in failed."
    click_on "Send unlock token"
    assert_equal current_path, "/unlock"
    fill_in "Email", with: "default4@example.com"
    assert_emails 1 do
      click_on "Send unlock token"
    end
    assert_selector ".message", text: "Unlock url has been sent to your email address (if user with that email address exists)."
    unlock_email = ActionMailer::Base.deliveries.last
    unlock_path = unlock_email.body.to_s.split("\n")[0].split(" ")[2] # NOTE: get XXX from "Unlock URL: XXX"
    visit unlock_path
    assert_selector ".message", text: "Unlocked you account successfully."
    click_on "Sign in"
    fill_in "Email", with: "default4@example.com"
    fill_in "Password", with: "password"
    click_on "Sign in"
    assert_selector ".message", text: "Signed in successfully."
    click_on "Sign out"
  end

  test "[default] (Recoverable) sign_up -> sign_in -> generate recover token -> password reset -> sign_in -> sign_out" do
    Aikotoba.config.recoverable = true
    Aikotoba::Account.create_by!(attributes: {email: "default5@example.com", password: "password"})
    visit "/sign_in"
    click_on "Send password reset token"
    assert_equal current_path, "/recover"
    fill_in "Email", with: "default5@example.com"
    assert_emails 1 do
      click_on "Send password reset token"
    end
    assert_selector ".message", text: "Password reset url has been sent to your email address (if user with that email address exists)."
    recover_email = ActionMailer::Base.deliveries.last
    recover_path = recover_email.body.to_s.split("\n")[0].split(" ")[3] # NOTE: get XXX from "Password reset URL: XXX"
    visit recover_path
    fill_in "Password", with: "updated_password"
    click_on "Password reset"
    assert_selector ".message", text: "Password reset you account successfully."
    fill_in "Email", with: "default5@example.com"
    fill_in "Password", with: "updated_password"
    click_on "Sign in"
    assert_selector ".message", text: "Signed in successfully."
    click_on "Sign out"
  end

  test "[default] (MagicLinkAuthenticatable) sign_in -> request sign in link -> sign in via link -> sign out" do
    Aikotoba.config.magic_link_authenticatable = true
    Aikotoba::Account.create_by!(attributes: {email: "default6@example.com", password: "password"})
    visit "/sign_in"
    click_on "Send sign in link"
    assert_equal current_path, "/magic_link"
    fill_in "Email", with: "default6@example.com"
    assert_emails 1 do
      click_on "Send sign in link"
    end
    assert_selector ".message", text: "Sign in url has been sent to your email address (if user with that email address exists)."
    magic_link_email = ActionMailer::Base.deliveries.last
    magic_link_path = magic_link_email.body.to_s.split("\n")[0].split(" ")[3] # NOTE: get XXX from "Sign in url: XXX"
    visit magic_link_path
    assert_selector ".message", text: "Signed in successfully."
    click_on "Sign out"
  end

  test "[default] (ALL) sign_up -> confirm -> sign_in -> lock -> unlock -> sign_in -> recover -> sign_in -> sign_out" do
    # Enable all features
    Aikotoba.config.registerable = true
    Aikotoba.config.confirmable = true
    Aikotoba.config.recoverable = true
    Aikotoba.config.lockable = true

    # Sign up
    visit "/sign_up"
    fill_in "Email", with: "all_default@example.com"
    fill_in "Password", with: "password"
    assert_emails 1 do
      click_on "Sign up"
    end
    assert_selector ".message", text: "Signed up successfully."

    # Confirmable: get confirm URL from email and visit it
    confirm_email = ActionMailer::Base.deliveries.last
    confirm_path = confirm_email.body.to_s.split("\n")[0].split(" ")[2]
    visit confirm_path
    assert_selector ".message", text: "Confirmed you email successfully."

    # Sign in
    click_on "Sign in"
    fill_in "Email", with: "all_default@example.com"
    fill_in "Password", with: "password"
    click_on "Sign in"
    assert_selector ".message", text: "Signed in successfully."
    click_on "Sign out"

    # Lockable: trigger lock and unlock via email
    assert_emails 1 do
      11.times do
        fill_in "Email", with: "all_default@example.com"
        fill_in "Password", with: "wrong password"
        click_on "Sign in"
      end
    end
    unlock_email = ActionMailer::Base.deliveries.last
    unlock_path = unlock_email.body.to_s.split("\n")[0].split(" ")[2]
    visit unlock_path
    assert_selector ".message", text: "Unlocked you account successfully."

    # Sign in again
    fill_in "Email", with: "all_default@example.com"
    fill_in "Password", with: "password"
    click_on "Sign in"
    assert_selector ".message", text: "Signed in successfully."
    click_on "Sign out"

    # Recoverable: request reset, visit link, reset, sign in
    click_on "Send password reset token"
    fill_in "Email", with: "all_default@example.com"
    assert_emails 1 do
      click_on "Send password reset token"
    end
    assert_selector ".message", text: "Password reset url has been sent to your email address (if user with that email address exists)."
    recover_email = ActionMailer::Base.deliveries.last
    recover_path = recover_email.body.to_s.split("\n")[0].split(" ")[3]
    visit recover_path
    fill_in "Password", with: "updated_password"
    click_on "Password reset"
    assert_selector ".message", text: "Password reset you account successfully."
    fill_in "Email", with: "all_default@example.com"
    fill_in "Password", with: "updated_password"
    click_on "Sign in"
    assert_selector ".message", text: "Signed in successfully."
    click_on "Sign out"
  end

  # Admin namespace tests
  test "[admin] create Aikotoba::Account -> sign_in -> sign_out" do
    admin = Admin.create(nickname: "admin_foo")
    Aikotoba::Account.create_by!(attributes: {email: "admin1@example.com", password: "password", authenticate_target: admin})
    visit "/admin/sign_in"
    fill_in "Email", with: "admin1@example.com"
    fill_in "Password", with: "password"
    click_on "Sign in"
    assert_selector ".message", text: "Signed in successfully."
    click_on "Sign out"
    assert_equal current_path, "/admin/sign_in"
  end

  test "[admin] visit protected page -> redirected to sign_in -> sign_in -> back to protected page" do
    admin = Admin.create(nickname: "admin_foo")
    Aikotoba::Account.create_by!(attributes: {email: "admin6@example.com", password: "password", authenticate_target: admin})
    visit "/admin/sensitives?from=protected"
    assert_current_path "/admin/sign_in"
    fill_in "Email", with: "admin6@example.com"
    fill_in "Password", with: "password"
    click_on "Sign in"
    assert_selector ".message", text: "Signed in successfully."
    assert_current_path "/admin/sensitives?from=protected"
    click_on "Sign out"
  end

  test "[admin] (Registerable) sign_in page offers no sign_up, since the scope sets authenticate_for" do
    Aikotoba.config.registerable = true
    visit "/admin/sign_in"
    assert_no_link I18n.t(".aikotoba.accounts.new")
    visit "/sign_in"
    assert_link I18n.t(".aikotoba.accounts.new"), href: "/sign_up"
  end

  test "[admin] (Confirmable) sign_up -> generate confirm token -> confirm -> sign_in -> sign_out" do
    Aikotoba.config.confirmable = true
    admin = Admin.create(nickname: "admin_foo")
    Aikotoba::Account.create_by!(attributes: {email: "admin3@example.com", password: "password", authenticate_target: admin})
    visit "/admin/sign_in"
    fill_in "Email", with: "admin3@example.com"
    fill_in "Password", with: "password"
    click_on "Sign in"
    assert_selector ".message", text: "Oops. Signed in failed."
    click_on "Send confirm token"
    assert_equal current_path, "/admin/confirm"
    fill_in "Email", with: "admin3@example.com"
    assert_emails 1 do
      click_on "Send confirm token"
    end
    assert_selector ".message", text: "Confirm url has been sent to your email address (if user with that email address exists)."
    confirm_email = ActionMailer::Base.deliveries.last
    confirm_path = confirm_email.body.to_s.split("\n")[0].split(" ")[2] # NOTE: get XXX from "Confirm URL: XXX"
    visit confirm_path
    assert_selector ".message", text: "Confirmed you email successfully."
    click_on "Sign in"
    fill_in "Email", with: "admin3@example.com"
    fill_in "Password", with: "password"
    click_on "Sign in"
    assert_selector ".message", text: "Signed in successfully."
    click_on "Sign out"
  end

  test "[admin] (Lockable) sign_up -> sign_in -> locked -> generate unlock token -> unlock -> sign_in -> sign_out" do
    Aikotoba.config.lockable = true
    admin = Admin.create(nickname: "admin_foo")
    Aikotoba::Account.create_by!(attributes: {email: "admin4@example.com", password: "password", authenticate_target: admin})
    visit "/admin/sign_in"
    11.times do
      fill_in "Email", with: "admin4@example.com"
      fill_in "Password", with: "wrong password"
      click_on "Sign in"
    end
    fill_in "Email", with: "admin4@example.com"
    fill_in "Password", with: "password"
    click_on "Sign in"
    assert_selector ".message", text: "Oops. Signed in failed."
    click_on "Send unlock token"
    assert_equal current_path, "/admin/unlock"
    fill_in "Email", with: "admin4@example.com"
    assert_emails 1 do
      click_on "Send unlock token"
    end
    assert_selector ".message", text: "Unlock url has been sent to your email address (if user with that email address exists)."
    unlock_email = ActionMailer::Base.deliveries.last
    unlock_path = unlock_email.body.to_s.split("\n")[0].split(" ")[2] # NOTE: get XXX from "Unlock URL: XXX"
    visit unlock_path
    assert_selector ".message", text: "Unlocked you account successfully."
    click_on "Sign in"
    fill_in "Email", with: "admin4@example.com"
    fill_in "Password", with: "password"
    click_on "Sign in"
    assert_selector ".message", text: "Signed in successfully."
    click_on "Sign out"
  end

  test "[admin] (Recoverable) sign_up -> sign_in -> generate recover token -> password reset -> sign_in -> sign_out" do
    Aikotoba.config.recoverable = true
    admin = Admin.create(nickname: "admin_foo")
    Aikotoba::Account.create_by!(attributes: {email: "admin5@example.com", password: "password", authenticate_target: admin})
    visit "/admin/sign_in"
    click_on "Send password reset token"
    assert_equal current_path, "/admin/recover"
    fill_in "Email", with: "admin5@example.com"
    assert_emails 1 do
      click_on "Send password reset token"
    end
    assert_selector ".message", text: "Password reset url has been sent to your email address (if user with that email address exists)."
    recover_email = ActionMailer::Base.deliveries.last
    recover_path = recover_email.body.to_s.split("\n")[0].split(" ")[3] # NOTE: get XXX from "Password reset URL: XXX"
    visit recover_path
    fill_in "Password", with: "updated_password"
    click_on "Password reset"
    assert_selector ".message", text: "Password reset you account successfully."
    fill_in "Email", with: "admin5@example.com"
    fill_in "Password", with: "updated_password"
    click_on "Sign in"
    assert_selector ".message", text: "Signed in successfully."
    click_on "Sign out"
  end

  test "[admin] (ALL) create Aikotoba::Account -> confirm -> sign_in -> lock -> unlock -> sign_in -> recover -> sign_in -> sign_out" do
    # Enable all features
    Aikotoba.config.registerable = true
    Aikotoba.config.confirmable = true
    Aikotoba.config.recoverable = true
    Aikotoba.config.lockable = true

    # NOTE: The admin scope sets authenticate_for, so it has no sign-up; create the account directly.
    admin = Admin.create(nickname: "admin_foo")
    Aikotoba::Account.create_by!(attributes: {email: "all_admin@example.com", password: "password", authenticate_target: admin})

    # Confirmable: request a confirm URL, then visit it
    visit "/admin/confirm"
    fill_in "Email", with: "all_admin@example.com"
    assert_emails 1 do
      click_on "Send confirm token"
    end
    confirm_email = ActionMailer::Base.deliveries.last
    confirm_path = confirm_email.body.to_s.split("\n")[0].split(" ")[2]
    visit confirm_path
    assert_selector ".message", text: "Confirmed you email successfully."

    # Sign in
    visit "/admin/sign_in"
    fill_in "Email", with: "all_admin@example.com"
    fill_in "Password", with: "password"
    click_on "Sign in"
    assert_selector ".message", text: "Signed in successfully."
    click_on "Sign out"

    # Lockable: trigger lock and unlock via email
    visit "/admin/sign_in"
    assert_emails 1 do
      11.times do
        fill_in "Email", with: "all_admin@example.com"
        fill_in "Password", with: "wrong password"
        click_on "Sign in"
      end
    end
    unlock_email = ActionMailer::Base.deliveries.last
    unlock_path = unlock_email.body.to_s.split("\n")[0].split(" ")[2]
    visit unlock_path
    assert_selector ".message", text: "Unlocked you account successfully."

    # Sign in again
    visit "/admin/sign_in"
    fill_in "Email", with: "all_admin@example.com"
    fill_in "Password", with: "password"
    click_on "Sign in"
    assert_selector ".message", text: "Signed in successfully."
    click_on "Sign out"

    # Recoverable: request reset, visit link, reset, sign in
    visit "/admin/sign_in"
    click_on "Send password reset token"
    fill_in "Email", with: "all_admin@example.com"
    assert_emails 1 do
      click_on "Send password reset token"
    end
    assert_selector ".message", text: "Password reset url has been sent to your email address (if user with that email address exists)."
    recover_email = ActionMailer::Base.deliveries.last
    recover_path = recover_email.body.to_s.split("\n")[0].split(" ")[3]
    visit recover_path
    fill_in "Password", with: "updated_password"
    click_on "Password reset"
    assert_selector ".message", text: "Password reset you account successfully."
    visit "/admin/sign_in"
    fill_in "Email", with: "all_admin@example.com"
    fill_in "Password", with: "updated_password"
    click_on "Sign in"
    assert_selector ".message", text: "Signed in successfully."
    click_on "Sign out"
  end

  # Test namespace isolation - ensure default and admin sessions are separate
  test "namespace isolation: default and admin sessions are separate" do
    # Create accounts for both namespaces
    Aikotoba::Account.create_by!(attributes: {email: "isolation_default@example.com", password: "password"})
    admin = Admin.create(nickname: "admin_foo")
    Aikotoba::Account.create_by!(attributes: {email: "isolation_admin@example.com", password: "password", authenticate_target: admin})

    # Sign in to default namespace
    visit "/sign_in"
    fill_in "Email", with: "isolation_default@example.com"
    fill_in "Password", with: "password"
    click_on "Sign in"
    assert_selector ".message", text: "Signed in successfully."
    assert_equal current_path, "/sensitives"

    # Visit admin sign in page - should not be authenticated
    visit "/admin/sensitives"
    assert_equal current_path, "/admin/sign_in"
    assert_selector "h1", text: "Sign in" # Should see sign in form

    # Back to default namespace - should still be authenticated
    visit "/sensitives"
    assert_selector "h1", text: "Sensitive Page"
    click_on "Sign out"

    # Sign in to admin namespace
    visit "/admin/sign_in"
    fill_in "Email", with: "isolation_admin@example.com"
    fill_in "Password", with: "password"
    click_on "Sign in"
    assert_selector ".message", text: "Signed in successfully."
    assert_equal current_path, "/admin/sensitives"

    # Visit default sign in page - should not be authenticated
    visit "/sensitives"
    assert_selector "h1", text: "Sign in" # Should see sign in form
    assert_equal current_path, "/sign_in"

    # Back to admin namespace - should still be authenticated
    visit "/admin/sensitives"
    assert_selector "h1", text: "Admin Sensitive Page"
    click_on "Sign out"
  end

  test "namespace isolation: signed out from one namespace does only sign out that namespace" do
    # Create accounts for both namespaces
    Aikotoba::Account.create_by!(attributes: {email: "isolation_default@example.com", password: "password"})
    admin = Admin.create(nickname: "admin_foo")
    Aikotoba::Account.create_by!(attributes: {email: "isolation_admin@example.com", password: "password", authenticate_target: admin})
    # Sign in to default namespace
    visit "/sign_in"
    fill_in "Email", with: "isolation_default@example.com"
    fill_in "Password", with: "password"
    click_on "Sign in"
    assert_selector ".message", text: "Signed in successfully."
    # Sign in to admin namespace
    visit "/admin/sign_in"
    fill_in "Email", with: "isolation_admin@example.com"
    fill_in "Password", with: "password"
    click_on "Sign in"
    assert_selector ".message", text: "Signed in successfully."
    # Sign out from default namespace
    visit "/sensitives"
    click_on "Sign out"
    assert_equal current_path, "/sign_in"
    # Verify admin namespace is also still signed in
    visit "/admin/sensitives"
    assert_equal current_path, "/admin/sensitives"
  end
end
