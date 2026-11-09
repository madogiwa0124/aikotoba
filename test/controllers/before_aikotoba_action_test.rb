# frozen_string_literal: true

require "test_helper"

# A before_action in the host app's ApplicationController runs before Aikotoba's own
# controllers, which inherit it, so it can stop a request before Aikotoba handles it. The dummy
# app blocks one IP from every Aikotoba page, as the README does.
class BeforeAikotobaActionTest < ActionDispatch::IntegrationTest
  def setup
    ActionController::Base.allow_forgery_protection = false
    Aikotoba.config.magic_link_authenticatable = true
    @account = Aikotoba::Account.create_by!(attributes: {email: "email@example.com", password: "password"})
    @blocked = {"REMOTE_ADDR" => ApplicationController::BLOCKED_IP}
  end

  test "a blocked IP can't sign in, and Aikotoba never authenticates" do
    assert_no_event_reported("aikotoba.sign_in") do
      assert_no_event_reported("aikotoba.sign_in_failed") do
        post aikotoba.create_session_path, params: {account: {email: @account.email, password: "password"}}, env: @blocked
      end
    end
    assert_response :forbidden
    assert_equal 0, @account.sessions.count
  end

  test "a blocked IP can't request a magic link either" do
    assert_no_emails do
      post aikotoba.create_magic_link_path, params: {account: {email: @account.email}}, env: @blocked
    end
    assert_response :forbidden
  end

  test "other IPs use Aikotoba as usual" do
    assert_event_reported("aikotoba.sign_in") do
      post aikotoba.create_session_path, params: {account: {email: @account.email, password: "password"}}
    end
  end

  test "the host app's own pages are left alone" do
    get "/sensitives", env: @blocked
    assert_redirected_to aikotoba.new_session_path
  end
end
