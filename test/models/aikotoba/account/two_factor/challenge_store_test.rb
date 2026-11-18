# frozen_string_literal: true

require "test_helper"

class Aikotoba::Account::TwoFactor::ChallengeStoreTest < ActiveSupport::TestCase
  def setup
    @session = {}
    @store = Aikotoba::Account::TwoFactor::ChallengeStore.new(session: @session, key: "aikotoba_session_token_two_factor")
    @account = Aikotoba::Account.create_by!(attributes: {email: "store@example.com", password: "password"})
  end

  def challenge(expires_at: 10.minutes.from_now, strategy: "email_otp")
    Aikotoba::Account::TwoFactor::Challenge.new(strategy: strategy, expires_at: expires_at)
  end

  test "start keeps only the account id, the strategy and the expiry, under its key" do
    freeze_time do
      @store.start(@account, challenge)
      assert_equal({"aikotoba_session_token_two_factor" => {"account_id" => @account.id, "strategy" => "email_otp", "expires_at" => 10.minutes.from_now.to_i}}, @session)
    end
  end

  test "current gives the account id and the strategy while the sign in can be finished" do
    @store.start(@account, challenge)
    assert @store.started?
    assert_equal({"account_id" => @account.id, "strategy" => "email_otp"}, @store.current)
  end

  test "nothing started: not started, and no current" do
    assert_not @store.started?
    assert_nil @store.current
  end

  # NOTE: current only reads, so started? still tells an expired one from none at all,
  #       whichever is asked first; the controller clears it.
  test "an expired one was started, but has no current, and stays until cleared" do
    @store.start(@account, challenge(expires_at: 1.second.ago))
    assert_nil @store.current
    assert @store.started?
    @store.clear
    assert_not @store.started?
  end

  test "one written for a strategy no longer registered has no current either" do
    @store.start(@account, challenge(strategy: "retired"))
    assert_nil @store.current
    assert @store.started?
  end

  test "a value that isn't what start wrote counts as none" do
    @session["aikotoba_session_token_two_factor"] = "tampered"
    assert @store.started?
    assert_nil @store.current
  end

  test "clear removes it and leaves the rest of the session alone" do
    @session["other"] = "kept"
    @store.start(@account, challenge)
    @store.clear
    assert_equal({"other" => "kept"}, @session)
  end
end
