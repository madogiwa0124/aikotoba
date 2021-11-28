# frozen_string_literal: true

class RequiredLoginControllerTest < ActionDispatch::IntegrationTest
  include Aikotoba::Test::AuthenticationHelper::Request

  def setup
    ActionController::Base.allow_forgery_protection = false
    @user = User.build_with_secret({})
    @user.save!
  end

  def requied_sign_in_path
    "/sensitives"
  end

  test "success after login access" do
    aikotoba_sign_in(@user)
    get requied_sign_in_path
    assert_equal 200, status
  end

  test "failed before login access" do
    get requied_sign_in_path
    assert_redirected_to Aikotoba.appeal_sign_in_path
    assert_equal I18n.t(".aikotoba.messages.authentication.required"), flash[:alert]
  end

  test "failed after logout access" do
    aikotoba_sign_in(@user)
    get requied_sign_in_path
    assert_equal 200, status
    aikotoba_sign_out
    get requied_sign_in_path
    assert_redirected_to Aikotoba.appeal_sign_in_path
    assert_equal I18n.t(".aikotoba.messages.authentication.required"), flash[:alert]
  end
end
