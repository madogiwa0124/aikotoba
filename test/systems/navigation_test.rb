require "test_helper"

class NavigationTest < ActionDispatch::SystemTestCase
  driven_by :rack_test

  test "sign_up -> sign_in -> sign_out" do
    visit Aikotoba.sign_up_path
    click_on "Sign up"
    assert_selector ".message", text: "Signed up successfully."
    # NOTE: get XXX from "Signed up successfully. Your Secret is XXX ."
    secret = page.first(".message").text.split(" ")[-2]
    fill_in "Secret",	with: secret
    click_on "Sign in"
    assert_selector ".message", text: "Signed in successfully."
    click_on "Sign out"
  end
end
