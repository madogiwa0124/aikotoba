# frozen_string_literal: true

require "test_helper"

class Aikotoba::SessionsControllerTest < ActionDispatch::IntegrationTest
  def setup
    ActionController::Base.allow_forgery_protection = false
    Aikotoba.confirmable = false
    email, password = ["email@example.com", "password"]
    @account = ::Aikotoba::Account.build_by(attributes: {email: email, password: password})
    @account.save!
  end

  test "success GET new_session_path" do
    get aikotoba.new_session_path
    assert_equal 200, status
    assert_select "h1", I18n.t(".aikotoba.sessions.new")
  end

  test "success POST new_session_path" do
    post aikotoba.new_session_path, params: {account: {email: @account.email, password: @account.password}}
    assert_redirected_to Aikotoba.after_sign_in_path
    assert_equal I18n.t(".aikotoba.messages.authentication.success"), flash[:notice]
  end

  test "failed POST new_session_path" do
    post aikotoba.new_session_path, params: {account: {email: @account.email, password: "invalid_password"}}
    assert_equal status, 422
    assert_equal I18n.t(".aikotoba.messages.authentication.failed"), flash[:alert]
  end

  test "success DELETE destroy_session_path" do
    post aikotoba.new_session_path, params: {account: {email: @account.email, password: @account.password}}
    assert_not_nil session[Aikotoba.session_key]
    delete aikotoba.destroy_session_path
    assert_nil session[Aikotoba.session_key]
    assert_redirected_to Aikotoba.after_sign_out_path
  end
end
