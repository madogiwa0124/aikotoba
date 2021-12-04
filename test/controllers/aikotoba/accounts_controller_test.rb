# frozen_string_literal: true

require "minitest/autorun"

class Aikotoba::AccountsControllerTest < ActionDispatch::IntegrationTest
  def setup
    ActionController::Base.allow_forgery_protection = false
  end

  test "success GET sign_up_path" do
    get Aikotoba.sign_up_path
    assert_equal 200, status
    assert_select "h1", I18n.t(".aikotoba.accounts.new")
  end

  test "success POST sign_up_path" do
    post Aikotoba.sign_up_path
    account = @controller.instance_variable_get("@account")
    assert_redirected_to Aikotoba.after_sign_up_path
    assert_equal I18n.t(".aikotoba.messages.registration.success", password: account.password), flash[:notice]
  end

  test "failed POST sign_up_path" do
    Aikotoba.password_digest_generator.stub(:call, nil) do
      post Aikotoba.sign_up_path
      assert_equal I18n.t(".aikotoba.messages.registration.failed"), flash[:alert]
    end
  end
end
