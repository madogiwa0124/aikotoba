# frozen_string_literal: true

require "test_helper"

class Aikotoba::Api::RefreshTokensTest < ActionDispatch::IntegrationTest
  include ApiCommitteeHelper

  def setup
    Aikotoba.api_authenticatable = true
    @email = "email@example.com"
    @password = "password"
    @account = Aikotoba::Account.build_by(attributes: {email: @email, password: @password})
    @account.save!
    post aikotoba.api_create_session_path, params: {account: {email: @email, password: @password}}, as: :json
    body = JSON.parse(response.body)
    @access_token = body["access_token"]
    @refresh_token = body["refresh_token"]
  end

  def teardown
    Aikotoba.api_authenticatable = false
  end

  test "POST api_refresh_session_path with valid refresh token returns 200 and new tokens" do
    post aikotoba.api_refresh_session_path, params: {refresh_token: @refresh_token}, as: :json
    assert_equal 200, status
    body = JSON.parse(response.body)
    assert body["access_token"].present?
    assert body["refresh_token"].present?
    assert_not_equal @access_token, body["access_token"]
    assert_not_equal @refresh_token, body["refresh_token"]
    assert_response_schema_confirm(200)
  end

  test "POST api_refresh_session_path with blank refresh token returns 400" do
    post aikotoba.api_refresh_session_path, params: {refresh_token: ""}, as: :json
    assert_equal 400, status
    assert_response_schema_confirm(400)
  end

  test "POST api_refresh_session_path with invalid refresh token format returns 400" do
    post aikotoba.api_refresh_session_path, params: {refresh_token: {key: "value"}}, as: :json
    assert_equal 400, status
    body = JSON.parse(response.body)
    assert_equal 400, body["status"]
    assert_response_schema_confirm(400)
  end

  test "POST api_refresh_session_path with invalid refresh token returns 401" do
    post aikotoba.api_refresh_session_path, params: {refresh_token: "invalid_token"}, as: :json
    assert_equal 401, status
    body = JSON.parse(response.body)
    assert_equal 401, body["status"]
    assert_response_schema_confirm(401)
  end

  test "POST api_refresh_session_path with expired refresh token returns 401 and revokes session" do
    session = Aikotoba::Account::Session.find_by_token(@access_token, origin: :api)
    session.refresh_token.update_column(:expired_at, 1.hour.ago)
    post aikotoba.api_refresh_session_path, params: {refresh_token: @refresh_token}, as: :json
    assert_equal 401, status
    assert_nil Aikotoba::Account::Session.find_by(id: session.id)
    assert_response_schema_confirm(401)
  end

  test "POST api_refresh_session_path with already-rotated refresh token returns 401" do
    post aikotoba.api_refresh_session_path, params: {refresh_token: @refresh_token}, as: :json
    assert_equal 200, status
    post aikotoba.api_refresh_session_path, params: {refresh_token: @refresh_token}, as: :json
    assert_equal 401, status
    assert_response_schema_confirm(401)
  end
end
