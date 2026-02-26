# frozen_string_literal: true

require "test_helper"

class Aikotoba::Api::SessionsTest < ActionDispatch::IntegrationTest
  include ApiCommitteeHelper

  def setup
    Aikotoba.api_authenticatable = true
    @email = "email@example.com"
    @password = "password"
    @account = Aikotoba::Account.build_by(attributes: {email: @email, password: @password})
    @account.save!
  end

  def teardown
    Aikotoba.api_authenticatable = false
    Aikotoba.confirmable = false
    Aikotoba.lockable = false
  end

  # POST create
  test "POST api_create_session_path with valid credentials returns 200 and tokens" do
    post aikotoba.api_create_session_path, params: {account: {email: @email, password: @password}}, as: :json
    assert_equal 200, status
    body = JSON.parse(response.body)
    assert body["access_token"].present?
    assert body["refresh_token"].present?
    assert_equal "Bearer", body["token_type"]
    assert body["expires_in"].is_a?(Integer)
    assert_response_schema_confirm(200)
  end

  test "POST api_create_session_path with wrong password returns 401" do
    post aikotoba.api_create_session_path, params: {account: {email: @email, password: "wrong_password"}}, as: :json
    assert_equal 401, status
    body = JSON.parse(response.body)
    assert_equal 401, body["status"]
    assert_response_schema_confirm(401)
  end

  test "POST api_create_session_path with unknown email returns 401" do
    post aikotoba.api_create_session_path, params: {account: {email: "unknown@example.com", password: @password}}, as: :json
    assert_equal 401, status
    assert_response_schema_confirm(401)
  end

  test "POST api_create_session_path with unconfirmed account returns 401" do
    Aikotoba.confirmable = true
    @account.update!(confirmed: false)
    post aikotoba.api_create_session_path, params: {account: {email: @email, password: @password}}, as: :json
    assert_equal 401, status
    assert_response_schema_confirm(401)
  end

  test "POST api_create_session_path with locked account returns 401" do
    Aikotoba.lockable = true
    Aikotoba::Account::Lock.lock!(account: @account)
    post aikotoba.api_create_session_path, params: {account: {email: @email, password: @password}}, as: :json
    assert_equal 401, status
    assert_response_schema_confirm(401)
  end

  test "POST api_create_session_path without account param returns 400 with Problem Details" do
    post aikotoba.api_create_session_path, params: {}, as: :json
    assert_equal 400, status
    body = JSON.parse(response.body)
    assert_equal 400, body["status"]
    assert body["title"].present?
    assert body["detail"].present?
    assert_includes response.content_type, "application/problem+json"
    assert_response_schema_confirm(400)
  end

  # DELETE destroy
  test "DELETE api_destroy_session_path with valid Bearer token returns 204" do
    post aikotoba.api_create_session_path, params: {account: {email: @email, password: @password}}, as: :json
    access_token = JSON.parse(response.body)["access_token"]
    delete aikotoba.api_destroy_session_path, headers: {"Authorization" => "Bearer #{access_token}"}
    assert_equal 204, status
    assert_response_schema_confirm(204)
  end

  test "DELETE api_destroy_session_path without Bearer token returns 204" do
    delete aikotoba.api_destroy_session_path
    assert_equal 204, status
    assert_response_schema_confirm(204)
  end

  test "DELETE api_destroy_session_path revokes session so subsequent requests return 401" do
    post aikotoba.api_create_session_path, params: {account: {email: @email, password: @password}}, as: :json
    access_token = JSON.parse(response.body)["access_token"]
    delete aikotoba.api_destroy_session_path, headers: {"Authorization" => "Bearer #{access_token}"}
    assert_equal 204, status
    get api_me_path, headers: {"Authorization" => "Bearer #{access_token}"}
    assert_equal 401, status
  end
end
