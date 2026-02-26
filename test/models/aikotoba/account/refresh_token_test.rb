# frozen_string_literal: true

require "test_helper"

class Aikotoba::Account::RefreshTokenTest < ActiveSupport::TestCase
  def setup
    @account = Aikotoba::Account.create!(
      email: "user@example.com",
      password: "Password1!",
      confirmed: true,
      locked: false,
      failed_attempts: 0
    )
    @session = Aikotoba::Account::Session.start!(
      account: @account,
      origin: :api,
      ip_address: "127.0.0.1",
      user_agent: "MiniTest",
      expired_at: Aikotoba.api_access_token_expiry.since
    )
  end

  test "after_initialize sets token and expired_at" do
    refresh_token = @session.refresh_token
    assert refresh_token.token.present?
    assert refresh_token.expired_at.future?
  end

  test "active? returns true for non-expired token" do
    assert @session.refresh_token.active?
  end

  test "active? returns false for expired token" do
    @session.refresh_token.update_column(:expired_at, 1.hour.ago)
    refute @session.refresh_token.active?
  end

  test "revoke! destroys the refresh token" do
    refresh_token = @session.refresh_token
    assert_difference "Aikotoba::Account::RefreshToken.count", -1 do
      refresh_token.revoke!
    end
  end

  test "session_must_be_api_origin validation fails for non-api session" do
    browser_session = Aikotoba::Account::Session.start!(
      account: @account,
      origin: "browser",
      ip_address: "127.0.0.1",
      user_agent: "MiniTest"
    )
    refresh_token = Aikotoba::Account::RefreshToken.new(session: browser_session)
    refute refresh_token.valid?
    assert_includes refresh_token.errors[:session], "must be api origin"
  end

  test "refresh! returns nil and revokes session when token is expired" do
    refresh_token = @session.refresh_token
    refresh_token.update_column(:expired_at, 1.hour.ago)
    assert_nil refresh_token.refresh!
    assert_nil Aikotoba::Account::Session.find_by(id: @session.id)
  end

  test "refresh! returns new session when token is active" do
    refresh_token = @session.refresh_token
    new_session = refresh_token.refresh!(origin: :api, ip_address: "127.0.0.1", user_agent: "MiniTest")
    assert new_session.persisted?
    assert new_session.origin_api?
    assert_nil Aikotoba::Account::Session.find_by(id: @session.id)
  end

  class Refresh < ActiveSupport::TestCase
    def setup
      @account = Aikotoba::Account.create!(
        email: "user@example.com",
        password: "Password1!",
        confirmed: true,
        locked: false,
        failed_attempts: 0
      )
      @session = Aikotoba::Account::Session.start!(
        account: @account,
        origin: :api,
        ip_address: "127.0.0.1",
        user_agent: "MiniTest",
        expired_at: Aikotoba.api_access_token_expiry.since
      )
      @refresh_token_value = @session.refresh_token.token
    end

    test "refresh_session! returns nil for blank token" do
      assert_nil Aikotoba::Account::RefreshToken.refresh_session!(refresh_token_value: "")
    end

    test "refresh_session! returns nil for unknown token" do
      assert_nil Aikotoba::Account::RefreshToken.refresh_session!(refresh_token_value: "unknown_token")
    end

    test "refresh_session! returns nil for expired token" do
      @session.refresh_token.update_column(:expired_at, 1.hour.ago)
      assert_nil Aikotoba::Account::RefreshToken.refresh_session!(refresh_token_value: @refresh_token_value)
    end

    test "refresh_session! returns new session for valid token" do
      new_session = Aikotoba::Account::RefreshToken.refresh_session!(
        refresh_token_value: @refresh_token_value,
        origin: :api,
        ip_address: "127.0.0.1",
        user_agent: "MiniTest"
      )
      assert new_session.persisted?
    end

    test "refresh_session! returns nil when using already-rotated token" do
      Aikotoba::Account::RefreshToken.refresh_session!(
        refresh_token_value: @refresh_token_value,
        origin: :api,
        ip_address: "127.0.0.1",
        user_agent: "MiniTest",
        expired_at: Aikotoba.api_access_token_expiry.since
      )
      assert_nil Aikotoba::Account::RefreshToken.refresh_session!(refresh_token_value: @refresh_token_value)
    end

    test "refresh_session! returns nil and does not create new session when lock cannot be acquired" do
      refresh_token = @session.refresh_token
      Aikotoba::Account::RefreshToken.stub(:find_by, refresh_token) do
        refresh_token.stub(:with_lock, ->(_) { raise ActiveRecord::LockWaitTimeout }) do
          assert_no_difference "Aikotoba::Account::Session.count" do
            assert_nil Aikotoba::Account::RefreshToken.refresh_session!(refresh_token_value: @refresh_token_value)
          end
        end
      end
    end

    test "refresh_session! returns nil and does not create new session when token record is deleted before lock acquired" do
      refresh_token = @session.refresh_token
      Aikotoba::Account::RefreshToken.stub(:find_by, refresh_token) do
        refresh_token.stub(:with_lock, ->(_) { raise ActiveRecord::RecordNotFound }) do
          assert_no_difference "Aikotoba::Account::Session.count" do
            assert_nil Aikotoba::Account::RefreshToken.refresh_session!(refresh_token_value: @refresh_token_value)
          end
        end
      end
    end
  end
end
