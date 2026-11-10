# frozen_string_literal: true

require "test_helper"

# NOTE: Sign in and sign up rate limits, keyed by IP as the README recommends.
class SignInRateLimitTest < ActionDispatch::IntegrationTest
  def setup
    ActionController::Base.allow_forgery_protection = false
    Aikotoba.config.sign_in_rate_limit_options = {to: 3, within: 1.minute, by: -> { request.remote_ip }}
    Aikotoba.config.registration_rate_limit_options = {to: 3, within: 1.minute, by: -> { request.remote_ip }}
    reload_controllers_with_rate_limit
    Rails.cache.clear
    @password = "password"
    @account = Aikotoba::Account.build_by(attributes: {email: "user@example.com", password: @password})
    @account.save!
  end

  # NOTE: The controllers read their rate limit options when they are loaded, which happens
  #       here, before test_helper restores the configuration, so clear them first.
  def teardown
    Aikotoba.config.sign_in_rate_limit_options = {}
    Aikotoba.config.registration_rate_limit_options = {}
    reload_controllers_with_rate_limit
    Rails.cache.clear
  end

  test "sign in is limited per IP across emails, and answered with 429" do
    3.times do |i|
      sign_in(email: "stuffed#{i}@example.com", password: "wrong")
      assert_response :unprocessable_entity
    end

    sign_in(email: @account.email, password: @password)
    assert_response :too_many_requests
    assert_nil cookies[Aikotoba.default_scope[:session_key]].presence
  end

  # NOTE: Like the token endpoints, so the host app answers every limited request in one place.
  #       The test env renders the exception as a 429, so this runs the before_action itself.
  test "a limited sign in or sign up raises TooManyRequests" do
    3.times { sign_in(email: "stuffed@example.com", password: "wrong") }
    3.times { post aikotoba.create_account_path, params: {account: {email: "new@example.com", password: "password"}}, env: {"REMOTE_ADDR" => "192.0.2.1"} }

    [Aikotoba::SessionsController, Aikotoba::AccountsController].each do |klass|
      assert_raises(ActionController::TooManyRequests, klass.name) { run_rate_limit(klass) }
    end
  end

  test "sign in from another IP is not limited" do
    3.times { sign_in(email: "stuffed@example.com", password: "wrong") }
    sign_in(email: "stuffed@example.com", password: "wrong")
    assert_response :too_many_requests

    sign_in(email: @account.email, password: @password, ip: "192.0.2.2")
    assert_redirected_to Aikotoba.default_scope[:after_sign_in_path]
  end

  test "sign in limit only counts create: showing the form and signing out are never limited" do
    sign_in(email: @account.email, password: @password)
    assert_redirected_to Aikotoba.default_scope[:after_sign_in_path]

    5.times do
      get aikotoba.new_session_path, env: {"REMOTE_ADDR" => "192.0.2.1"}
      assert_response :redirect
    end
    delete aikotoba.destroy_session_path, env: {"REMOTE_ADDR" => "192.0.2.1"}
    assert_redirected_to Aikotoba.default_scope[:after_sign_out_path]
    5.times do
      get aikotoba.new_session_path, env: {"REMOTE_ADDR" => "192.0.2.1"}
      assert_response :ok
    end

    2.times { sign_in(email: @account.email, password: "wrong") }
    sign_in(email: @account.email, password: "wrong")
    assert_response :too_many_requests
  end

  # NOTE: The default scope authenticates every account, admins included, so a counter per scope
  #       would only give an attacker one more budget against the same accounts.
  test "sign in counter is shared between scopes" do
    3.times { sign_in(email: "stuffed@example.com", password: "wrong") }

    post aikotoba.admin_create_session_path, params: {account: {email: "stuffed@example.com", password: "wrong"}}, env: {"REMOTE_ADDR" => "192.0.2.1"}
    assert_response :too_many_requests
  end

  # NOTE: Rails' default scope: is the controller_path of the request's controller, which a
  #       subclass changes, so without a fixed scope: a host app routing one would double the budget.
  #       Runs the before_action the subclass inherits, as a request routed to it would.
  test "a host app's subclass counts against the engine's sign in limit" do
    subclass = Class.new(Aikotoba::SessionsController) { def self.name = "HostLoginController" }
    assert_equal "host_login", subclass.controller_path

    3.times { sign_in(email: "stuffed@example.com", password: "wrong") }

    assert_raises(ActionController::TooManyRequests) { run_rate_limit(subclass) }
  end

  test "sign in honours with: and only: from the options" do
    Aikotoba.config.sign_in_rate_limit_options = {
      to: 1, within: 1.minute, by: -> { request.remote_ip }, only: %i[new create],
      with: -> { head :service_unavailable }
    }
    reload_controllers_with_rate_limit

    get aikotoba.new_session_path
    assert_response :ok
    get aikotoba.new_session_path
    assert_response :service_unavailable
  end

  test "sign up is limited per IP and answered with 429" do
    3.times do |i|
      post aikotoba.create_account_path, params: {account: {email: "new#{i}@example.com", password: "password"}}
      assert_response :redirect
    end

    assert_no_difference -> { Aikotoba::Account.count } do
      post aikotoba.create_account_path, params: {account: {email: "new4@example.com", password: "password"}}
    end
    assert_response :too_many_requests
  end

  test "sign up limit counts existing emails too, so it caps the existence check" do
    3.times do
      post aikotoba.create_account_path, params: {account: {email: @account.email, password: "password"}}
      assert_response :unprocessable_entity
    end

    post aikotoba.create_account_path, params: {account: {email: @account.email, password: "password"}}
    assert_response :too_many_requests
    assert_select "body", text: /has already been taken/, count: 0
  end

  test "sign up form itself is not limited" do
    5.times do
      get aikotoba.new_account_path
      assert_response :ok
    end
  end

  test "nothing is limited when the options are empty" do
    Aikotoba.config.sign_in_rate_limit_options = {}
    Aikotoba.config.registration_rate_limit_options = {}
    reload_controllers_with_rate_limit

    5.times do
      sign_in(email: "stuffed@example.com", password: "wrong")
      assert_response :unprocessable_entity
    end
  end

  private

  def sign_in(email:, password:, ip: "192.0.2.1")
    post aikotoba.create_session_path, params: {account: {email: email, password: password}}, env: {"REMOTE_ADDR" => ip}
  end

  # NOTE: Runs the rate limit before_action of a controller class, as a request from 192.0.2.1 would.
  def run_rate_limit(klass)
    controller = klass.new
    controller.set_request!(ActionDispatch::TestRequest.create("REMOTE_ADDR" => "192.0.2.1"))
    rate_limit = klass._process_action_callbacks.find { |callback| callback.kind == :before && callback.filter.is_a?(Proc) }
    controller.instance_exec(&rate_limit.filter)
  end

  # NOTE: rate_limit is evaluated at the time of Class definition,
  #       so it is necessary to explicitly reload the Controller after changing the settings
  def reload_controllers_with_rate_limit
    Aikotoba.send(:remove_const, :SessionsController) if Aikotoba.const_defined?(:SessionsController)
    Aikotoba.send(:remove_const, :AccountsController) if Aikotoba.const_defined?(:AccountsController)

    load Rails.root.join("../../app/controllers/aikotoba/sessions_controller.rb")
    load Rails.root.join("../../app/controllers/aikotoba/accounts_controller.rb")
  end
end
