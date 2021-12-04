# frozen_string_literal: true

class Aikotoba::SessionsControllerTest < ActionDispatch::IntegrationTest
  def setup
    ActionController::Base.allow_forgery_protection = false
    @account = ::Aikotoba::Account.build_account_by({})
    @account.save!
  end

  test "success GET sign_in_path" do
    get Aikotoba.sign_in_path
    assert_equal 200, status
    assert_select "h1", I18n.t(".aikotoba.sessions.new")
  end

  test "success POST sign_in_path" do
    post Aikotoba.sign_in_path, params: {account: {password: @account.password}}
    assert_redirected_to Aikotoba.after_sign_in_path
    assert_equal I18n.t(".aikotoba.messages.authentication.success"), flash[:notice]
  end

  test "failed POST sign_in_path" do
    post Aikotoba.sign_in_path, params: {account: {password: "invalid_password"}}
    assert_redirected_to Aikotoba.failed_sign_in_path
    assert_equal I18n.t(".aikotoba.messages.authentication.failed"), flash[:alert]
  end

  test "success DELETE sign_out_path" do
    post Aikotoba.sign_in_path, params: {account: {password: @account.password}}
    assert_not_nil session[Aikotoba.session_key]
    delete Aikotoba.sign_out_path
    assert_nil session[Aikotoba.session_key]
    assert_redirected_to Aikotoba.after_sign_out_path
  end
end
