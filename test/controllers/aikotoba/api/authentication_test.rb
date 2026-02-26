# frozen_string_literal: true

require "test_helper"

class Aikotoba::Api::AuthenticationTest < ActionDispatch::IntegrationTest
  def setup
    Aikotoba.api_authenticatable = true
    ActionController::Base.allow_forgery_protection = false

    @email = "api_user@example.com"
    @password = "secured_password"
    @account = ::Aikotoba::Account.build_by(attributes: {email: @email, password: @password})
    @account.save!
  end

  def teardown
    Aikotoba.api_authenticatable = false
    Aikotoba.confirmable = false
    Aikotoba.lockable = false
  end

  # ===========================================================================
  # Happy path
  # ===========================================================================

  test "sign in → access /api/me → sign out → old token is invalidated" do
    # Sign in and obtain tokens
    post aikotoba.api_create_session_path,
      params: {account: {email: @email, password: @password}},
      as: :json

    assert_response :ok
    body = response.parsed_body
    assert body["access_token"].present?, "access_token should be returned"
    assert body["refresh_token"].present?, "refresh_token should be returned"
    assert_equal "Bearer", body["token_type"]
    assert body["expires_in"].is_a?(Integer), "expires_in should be an integer"
    assert body["expires_in"] > 0

    access_token = body["access_token"]

    # The obtained access token can access /api/me
    get api_me_path,
      headers: bearer(access_token),
      as: :json

    assert_response :ok
    body = response.parsed_body
    assert_equal @account.id, body.dig("account", "id")

    # Sign out returns 204 No Content
    delete aikotoba.api_destroy_session_path,
      headers: bearer(access_token),
      as: :json

    assert_response :no_content

    # After sign out, the same access token cannot access /api/me
    get api_me_path,
      headers: bearer(access_token),
      as: :json

    assert_response :unauthorized
  end

  test "sign in → refresh → access /api/me with new access token" do
    # Sign in and obtain tokens
    post aikotoba.api_create_session_path,
      params: {account: {email: @email, password: @password}},
      as: :json

    assert_response :ok
    body = response.parsed_body
    old_refresh_token = body["refresh_token"]

    # Refresh to obtain a new token set
    post aikotoba.api_refresh_session_path,
      params: {refresh_token: old_refresh_token},
      as: :json

    assert_response :ok
    body = response.parsed_body
    new_access_token = body["access_token"]
    new_refresh_token = body["refresh_token"]

    assert new_access_token.present?, "new access_token should be returned"
    assert new_refresh_token.present?, "new refresh_token should be returned"
    assert_not_equal old_refresh_token, new_refresh_token, "refresh_token should be rotated"

    # The new access token can access /api/me
    get api_me_path,
      headers: bearer(new_access_token),
      as: :json

    assert_response :ok
    assert_equal @account.id, response.parsed_body.dig("account", "id")
  end

  test "old refresh token cannot be reused after rotation (token rotation)" do
    # Sign in
    post aikotoba.api_create_session_path,
      params: {account: {email: @email, password: @password}},
      as: :json

    old_refresh_token = response.parsed_body["refresh_token"]

    # The first refresh succeeds
    post aikotoba.api_refresh_session_path,
      params: {refresh_token: old_refresh_token},
      as: :json

    assert_response :ok

    # Attempting to refresh again with the old refresh token fails
    post aikotoba.api_refresh_session_path,
      params: {refresh_token: old_refresh_token},
      as: :json

    assert_response :unauthorized
    body = response.parsed_body
    assert_equal 401, body["status"]
    assert body["detail"].present?
  end

  test "old access token is invalidated after refresh" do
    # Sign in
    post aikotoba.api_create_session_path,
      params: {account: {email: @email, password: @password}},
      as: :json

    body = response.parsed_body
    old_access_token = body["access_token"]
    old_refresh_token = body["refresh_token"]

    # Refresh
    post aikotoba.api_refresh_session_path,
      params: {refresh_token: old_refresh_token},
      as: :json

    assert_response :ok

    # The old access token cannot access /api/me
    get api_me_path,
      headers: bearer(old_access_token),
      as: :json

    assert_response :unauthorized
  end

  test "DELETE /sessions/current no content after sign out" do
    # Sign in
    post aikotoba.api_create_session_path,
      params: {account: {email: @email, password: @password}},
      as: :json

    access_token = response.parsed_body["access_token"]

    # The first sign out succeeds
    delete aikotoba.api_destroy_session_path,
      headers: bearer(access_token),
      as: :json

    assert_response :no_content

    # Attempting to sign out again with the same token fails authentication
    delete aikotoba.api_destroy_session_path,
      headers: bearer(access_token),
      as: :json

    assert_response :no_content
  end

  # ===========================================================================
  # Unhappy path
  # ===========================================================================

  test "sign in fails with wrong password" do
    post aikotoba.api_create_session_path,
      params: {account: {email: @email, password: "wrong_password"}},
      as: :json

    assert_response :unauthorized
    body = response.parsed_body
    assert_equal 401, body["status"]
    assert body["title"].present?
    assert body["detail"].present?
  end

  test "access to authenticated endpoint fails without Authorization header" do
    get api_me_path, as: :json

    assert_response :unauthorized
  end

  test "access fails with invalid access token" do
    get api_me_path,
      headers: bearer("totally_invalid_token"),
      as: :json

    assert_response :unauthorized
  end

  test "access fails with expired access token" do
    # Sign in
    post aikotoba.api_create_session_path,
      params: {account: {email: @email, password: @password}},
      as: :json

    access_token = response.parsed_body["access_token"]

    # Expire the session in the DB
    Aikotoba::Account::Session.find_by!(token: access_token)
      .update_columns(expired_at: 1.minute.ago)

    get api_me_path,
      headers: bearer(access_token),
      as: :json

    assert_response :unauthorized
  end

  test "refresh fails with invalid refresh token" do
    post aikotoba.api_refresh_session_path,
      params: {refresh_token: "invalid_refresh_token_value"},
      as: :json

    assert_response :unauthorized
    body = response.parsed_body
    assert_equal 401, body["status"]
    assert body["detail"].present?
  end

  test "refresh fails with expired refresh token and associated session is revoked" do
    # Sign in
    post aikotoba.api_create_session_path,
      params: {account: {email: @email, password: @password}},
      as: :json

    body = response.parsed_body
    access_token = body["access_token"]
    refresh_token_value = body["refresh_token"]

    # Expire the refresh token in the DB
    Aikotoba::Account::RefreshToken.find_by!(token: refresh_token_value)
      .update_columns(expired_at: 1.minute.ago)

    # Refresh fails
    post aikotoba.api_refresh_session_path,
      params: {refresh_token: refresh_token_value},
      as: :json

    assert_response :unauthorized

    # The associated session is also revoked when expiry is detected,
    # so the old access token cannot access /api/me either
    get api_me_path,
      headers: bearer(access_token),
      as: :json

    assert_response :unauthorized
  end

  # ===========================================================================
  # Feature flag combinations
  # ===========================================================================

  test "unconfirmed account cannot sign in when Confirmable is enabled" do
    Aikotoba.confirmable = true
    @account.update!(confirmed: false)

    post aikotoba.api_create_session_path,
      params: {account: {email: @email, password: @password}},
      as: :json

    assert_response :unauthorized
  end

  test "locked account cannot sign in when Lockable is enabled" do
    Aikotoba.lockable = true
    @account.update!(locked: true)

    post aikotoba.api_create_session_path,
      params: {account: {email: @email, password: @password}},
      as: :json

    assert_response :unauthorized
  end

  test "sign in is not available when api_authenticatable is disabled" do
    Aikotoba.api_authenticatable = false

    post aikotoba.api_create_session_path,
      params: {account: {email: @email, password: @password}},
      as: :json

    assert_response :not_found
  end

  private

  def bearer(token)
    {"Authorization" => "Bearer #{token}"}
  end
end
