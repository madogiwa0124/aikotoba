require "test_helper"

class Aikotoba::Account::SessionTest < ActiveSupport::TestCase
  class Initialization < ActiveSupport::TestCase
    def setup
      @account = Aikotoba::Account.create!(
        email: "user@example.com",
        password: "Password1!",
        confirmed: true,
        locked: false,
        failed_attempts: 0
      )
    end

    test "after_initialize sets token and expired_at" do
      session = Aikotoba::Account::Session.new(account: @account)
      assert session.token.present?
      assert session.expired_at.future?
      assert_equal session.account, @account
    end
  end

  class Scopes < ActiveSupport::TestCase
    def setup
      @account = Aikotoba::Account.create!(
        email: "user@example.com",
        password: "Password1!",
        confirmed: true,
        locked: false,
        failed_attempts: 0
      )
    end

    test "active scope returns non-expired sessions" do
      active = Aikotoba::Account::Session.create!(account: @account)
      expired = Aikotoba::Account::Session.create!(account: @account, expired_at: 1.hour.ago)

      result = Aikotoba::Account::Session.active.to_a
      assert_includes result, active
      refute_includes result, expired
    end

    test "authenticatable scope filters via account confirmed/unlocked" do
      Aikotoba.confirmable = true
      unconfirmed = Aikotoba::Account.create!(
        email: "locked@example.com",
        password: "Password1!",
        confirmed: false
      )
      Aikotoba::Account::Session.create!(account: unconfirmed)
      s1 = Aikotoba::Account::Session.create!(account: @account)

      authenticatable = Aikotoba::Account::Session.authenticatable.to_a

      assert_equal authenticatable, [s1]
      Aikotoba.confirmable = false
    end
  end

  def setup
    @account = Aikotoba::Account.create!(
      email: "user@example.com",
      password: "Password1!",
      confirmed: true,
      locked: false,
      failed_attempts: 0
    )
  end

  test "revoke! destroys the session" do
    session = Aikotoba::Account::Session.create!(account: @account)
    assert_difference "Aikotoba::Account::Session.count", -1 do
      session.revoke!
    end
  end

  test "start!(account:) creates session with meta" do
    s = Aikotoba::Account::Session.start!(
      account: @account,
      ip_address: "127.0.0.1",
      user_agent: "MiniTest"
    )

    assert s.persisted?
    assert_equal @account.id, s.account.id
    assert_equal "127.0.0.1", s.ip_address
    assert_equal "MiniTest", s.user_agent
    assert s.token.present?
    assert s.expired_at.present?
  end

  test "find_by_token returns active authenticatable session" do
    Aikotoba.confirmable = true
    s = Aikotoba::Account::Session.create!(account: @account)
    assert_equal s, Aikotoba::Account::Session.find_by_token(s.token)

    # NOTE: Expired session is not returned.
    expired = Aikotoba::Account::Session.create!(account: @account, expired_at: 1.hour.ago)
    assert_nil Aikotoba::Account::Session.find_by_token(expired.token)

    # NOTE: Session for unconfirmed account is not returned.
    unconfirmed_account = Aikotoba::Account.create!(
      email: "unconfirmed@example.com",
      password: "Password1!",
      confirmed: false
    )
    unconfirmed_session = Aikotoba::Account::Session.create!(account: unconfirmed_account)
    assert_nil Aikotoba::Account::Session.find_by_token(unconfirmed_session.token)
    Aikotoba.confirmable = false
  end
end
