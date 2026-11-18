# frozen_string_literal: true

require "test_helper"

# NOTE: aikotoba_sign_in starts a session right away, so in a scope that requires a second
#       factor it refuses to unless the caller says the factor was passed (two_factor: :verified).
class DirectSignInTest < ActionDispatch::IntegrationTest
  def setup
    ActionController::Base.allow_forgery_protection = false
    @account = Aikotoba::Account.create_by!(attributes: {email: "direct_sign_in@example.com", password: "password"})
  end

  def sign_in_directly(two_factor: nil)
    post "/direct_sign_in", params: {email: @account.email, two_factor: two_factor}
  end

  test "signs in without two_factor: in a scope that doesn't require a second factor" do
    assert_difference "Aikotoba::Account::Session.count", 1 do
      sign_in_directly
    end
    assert_response :no_content
  end

  # NOTE: An integration test only sees the 500 page Rails renders for the error.
  test "raises without two_factor: in a scope that requires a second factor, before signing in" do
    Aikotoba.config.default_scope[:two_factor_authenticatable] = true
    assert_no_difference "Aikotoba::Account::Session.count" do
      assert_no_event_reported("aikotoba.sign_in") { sign_in_directly }
    end
    assert_response :internal_server_error
  end

  test "signs in with two_factor: :verified in a scope that requires a second factor" do
    Aikotoba.config.default_scope[:two_factor_authenticatable] = true
    assert_difference "Aikotoba::Account::Session.count", 1 do
      sign_in_directly(two_factor: "verified")
    end
    assert_response :no_content
  end
end

# NOTE: A controller test, which raises the error itself rather than rendering a 500 page, to
#       check which error it is.
class DirectSignInErrorTest < ActionController::TestCase
  tests DirectSignInsController

  def setup
    ActionController::Base.allow_forgery_protection = false
    @account = Aikotoba::Account.create_by!(attributes: {email: "direct_sign_in_error@example.com", password: "password"})
  end

  test "raises Errors::TwoFactorRequired, pointing at aikotoba_begin_sign_in" do
    Aikotoba.config.default_scope[:two_factor_authenticatable] = true
    error = assert_raises(Aikotoba::Errors::TwoFactorRequired) do
      post :create, params: {email: @account.email}
    end
    assert_match(/aikotoba_begin_sign_in/, error.message)
    assert_equal 0, Aikotoba::Account::Session.count
  end

  test "raises ArgumentError on any other two_factor:, whatever the scope requires" do
    # NOTE: :skip was accepted while magic link sign in, its only caller, existed.
    %w[yes skip].each do |reason|
      assert_raises(ArgumentError) do
        post :create, params: {email: @account.email, two_factor: reason}
      end
    end
    assert_equal 0, Aikotoba::Account::Session.count
  end
end
