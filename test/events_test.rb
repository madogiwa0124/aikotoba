# frozen_string_literal: true

require "test_helper"

# NOTE: Tests here change Aikotoba.config without restoring it: test_helper.rb swaps the booted
#       configuration back in after every test. assert_event_reported matches payloads
#       partially, so an expected payload may leave out keys it doesn't check.
class Aikotoba::EventsTest < ActiveSupport::TestCase
  def setup
    @email = "email@example.com"
    @password = "password"
  end

  def create_account
    Aikotoba::Account.create_by!(attributes: {email: @email, password: @password})
  end

  test "every event is named after its constant, and only sign_in_failed skips the commit wait" do
    events = Aikotoba::Event.constants.map { |name| Aikotoba::Event.const_get(name) }
    events.each do |event|
      assert_equal "aikotoba.#{event.name.demodulize.underscore}", event.event_name
    end
    assert_equal [Aikotoba::Event::SignInFailed], events.reject(&:after_commit?)
  end

  test "an event raises on a missing or unknown payload key, and reports nothing" do
    assert_no_event_reported("aikotoba.account_locked") do
      assert_raises(ArgumentError) { Aikotoba::Event::AccountLocked.report }
      assert_raises(ArgumentError) { Aikotoba::Event::AccountLocked.report(account_id: 1, email: "email@example.com") }
    end
  end

  test "register! reports account_registered once the account is saved" do
    account = Aikotoba::Account.build_by(attributes: {email: @email, password: @password})
    event = assert_event_reported("aikotoba.account_registered") { account.register! }

    assert_equal({account_id: account.id}, event[:payload])
  end

  test "register! reports nothing when the save fails" do
    account = Aikotoba::Account.build_by(attributes: {email: @email, password: "short"})
    assert_no_event_reported("aikotoba.account_registered") do
      assert_raises(ActiveRecord::RecordInvalid) { account.register! }
    end
  end

  test "an event is dropped when the caller's transaction rolls back" do
    account = Aikotoba::Account.build_by(attributes: {email: @email, password: @password})
    assert_no_event_reported("aikotoba.account_registered") do
      ActiveRecord::Base.transaction do
        account.register!
        raise ActiveRecord::Rollback
      end
    end
  end

  test "an event waits for the caller's transaction to commit" do
    account = Aikotoba::Account.build_by(attributes: {email: @email, password: @password})
    assert_event_reported("aikotoba.account_registered") do
      ActiveRecord::Base.transaction do
        assert_no_event_reported("aikotoba.account_registered") { account.register! }
      end
    end
  end

  test "register! with confirmable also reports confirmation_token_issued" do
    Aikotoba.config.confirmable = true
    account = Aikotoba::Account.build_by(attributes: {email: @email, password: @password})
    assert_events_reported([
      {name: "aikotoba.confirmation_token_issued", payload: {notified: true}},
      {name: "aikotoba.account_registered"}
    ]) { account.register! }
    assert account.persisted?
  end

  test "authenticate_by reports sign_in_failed with the account on a wrong password" do
    account = create_account
    assert_event_reported("aikotoba.sign_in_failed", payload: {email: @email, account_id: account.id, target_type_name: nil}) do
      assert_nil Aikotoba::Account::PasswordHash.authenticate_by(attributes: {email: @email, password: "wrong_password"})
    end
  end

  test "authenticate_by reports sign_in_failed without an account for an unknown email or a blank password" do
    create_account
    assert_event_reported("aikotoba.sign_in_failed", payload: {email: "unknown@example.com", account_id: nil, target_type_name: "Admin"}) do
      Aikotoba::Account::PasswordHash.authenticate_by(attributes: {email: "unknown@example.com", password: @password}, target_type_name: "Admin")
    end
    assert_event_reported("aikotoba.sign_in_failed", payload: {email: @email, account_id: nil, target_type_name: nil}) do
      Aikotoba::Account::PasswordHash.authenticate_by(attributes: {email: @email, password: ""})
    end
  end

  test "sign_in_failed reports the email normalized the way the account is looked up" do
    account = create_account
    assert_event_reported("aikotoba.sign_in_failed", payload: {email: @email, account_id: account.id}) do
      Aikotoba::Account::PasswordHash.authenticate_by(attributes: {email: "  EMail@Example.COM ", password: "wrong_password"})
    end
    assert_event_reported("aikotoba.sign_in_failed", payload: {email: "unknown@example.com", account_id: nil}) do
      Aikotoba::Account::PasswordHash.authenticate_by(attributes: {email: " Unknown@Example.com ", password: @password})
    end
    assert_event_reported("aikotoba.sign_in_failed", payload: {email: @email, account_id: nil}) do
      Aikotoba::Account::PasswordHash.authenticate_by(attributes: {email: " EMAIL@example.com", password: ""})
    end
  end

  test "sign_in_failed reports a nil or blank email without raising" do
    assert_event_reported("aikotoba.sign_in_failed", payload: {email: nil, account_id: nil}) do
      Aikotoba::Account::PasswordHash.authenticate_by(attributes: {email: nil, password: ""})
    end
    assert_event_reported("aikotoba.sign_in_failed", payload: {email: nil, account_id: nil}) do
      Aikotoba::Account::PasswordHash.authenticate_by(attributes: {email: nil, password: @password})
    end
    assert_event_reported("aikotoba.sign_in_failed", payload: {email: "", account_id: nil}) do
      Aikotoba::Account::PasswordHash.authenticate_by(attributes: {email: "   ", password: @password})
    end
  end

  test "sign_in_failed's email is masked by the app's filter_parameters" do
    create_account
    original = ActiveSupport.filter_parameters
    ActiveSupport.filter_parameters = [:email]
    Rails.event.reload_payload_filter
    assert_event_reported("aikotoba.sign_in_failed", payload: {email: "[FILTERED]"}) do
      Aikotoba::Account::PasswordHash.authenticate_by(attributes: {email: @email, password: "wrong_password"})
    end
  ensure
    ActiveSupport.filter_parameters = original
    Rails.event.reload_payload_filter
  end

  test "authenticate_by reports nothing on success, which aikotoba_sign_in reports" do
    create_account
    assert_no_event_reported("aikotoba.sign_in_failed") do
      assert Aikotoba::Account::PasswordHash.authenticate_by(attributes: {email: @email, password: @password})
    end
  end

  test "too many failed sign ins report account_locked and unlock_token_issued" do
    Aikotoba.config.lockable = true
    Aikotoba.config.max_failed_attempts = 1
    account = create_account
    Aikotoba::Account::PasswordHash.authenticate_by(attributes: {email: @email, password: "wrong_password"})
    assert_events_reported([
      {name: "aikotoba.unlock_token_issued", payload: {account_id: account.id, notified: true}},
      {name: "aikotoba.account_locked", payload: {account_id: account.id}},
      {name: "aikotoba.sign_in_failed", payload: {account_id: account.id}}
    ]) do
      Aikotoba::Account::PasswordHash.authenticate_by(attributes: {email: @email, password: "wrong_password"})
    end
  end

  test "unlock! reports account_unlocked" do
    account = create_account
    Aikotoba::Account::Lock.lock!(account: account)
    assert_event_reported("aikotoba.account_unlocked", payload: {account_id: account.id}) do
      Aikotoba::Account::Lock.unlock!(account: account)
    end
  end

  test "issuing a token reports *_token_issued, saying whether its email was sent" do
    account = create_account
    assert_events_reported([
      {name: "aikotoba.confirmation_token_issued", payload: {account_id: account.id, notified: false}},
      {name: "aikotoba.recovery_token_issued", payload: {account_id: account.id, notified: true}},
      {name: "aikotoba.unlock_token_issued", payload: {account_id: account.id, notified: true}}
    ]) do
      Aikotoba::Account::Confirmation.create_token!(account: account)
      Aikotoba::Account::Recovery.create_token!(account: account, notify: true)
      Aikotoba::Account::Lock.create_token!(account: account, notify: true)
    end
  end

  test "confirm! reports account_confirmed" do
    account = create_account
    assert_event_reported("aikotoba.account_confirmed", payload: {account_id: account.id}) do
      Aikotoba::Account::Confirmation.confirm!(account: account)
    end
  end

  test "recover! reports password_recovered, and nothing when the new password is invalid" do
    account = create_account
    assert_no_event_reported("aikotoba.password_recovered") do
      assert_raises(ActiveRecord::RecordInvalid) { Aikotoba::Account::Recovery.recover!(account: account, new_password: "short") }
    end
    assert_event_reported("aikotoba.password_recovered", payload: {account_id: account.id}) do
      Aikotoba::Account::Recovery.recover!(account: account, new_password: "new_password")
    end
  end
end

class Aikotoba::EventsSignInTest < ActionDispatch::IntegrationTest
  def setup
    ActionController::Base.allow_forgery_protection = false
    @email = "email@example.com"
    @password = "password"
    @account = Aikotoba::Account.create_by!(attributes: {email: @email, password: @password})
  end

  test "signing in and out reports sign_in and sign_out with the session and the scope" do
    sign_in = assert_event_reported("aikotoba.sign_in", payload: {account_id: @account.id, scope: "default"}) do
      post aikotoba.create_session_path, params: {account: {email: @email, password: @password}}
    end
    session_id = sign_in[:payload][:session_id]
    assert_equal "127.0.0.1", Aikotoba::Account::Session.find(session_id).ip_address

    assert_event_reported("aikotoba.sign_out", payload: {account_id: @account.id, session_id: session_id, scope: "default"}) do
      delete aikotoba.destroy_session_path
    end
  end

  test "signing in to another scope reports that scope" do
    admin = Admin.create!(nickname: "admin")
    admin_account = Aikotoba::Account.create_by!(attributes: {email: "admin@example.com", password: @password, authenticate_target: admin})
    assert_event_reported("aikotoba.sign_in", payload: {account_id: admin_account.id, scope: "admin"}) do
      post aikotoba.admin_create_session_path, params: {account: {email: "admin@example.com", password: @password}}
    end
  end

  test "a failed sign in reports sign_in_failed and no sign_in" do
    assert_no_event_reported("aikotoba.sign_in") do
      assert_event_reported("aikotoba.sign_in_failed") do
        post aikotoba.create_session_path, params: {account: {email: @email, password: "wrong_password"}}
      end
    end
  end

  test "aikotoba_sign_out revokes the session and reports sign_out even if nothing read it first" do
    post aikotoba.create_session_path, params: {account: {email: @email, password: @password}}
    session_id = Aikotoba::Account::Session.last.id
    assert_event_reported("aikotoba.sign_out", payload: {account_id: @account.id, session_id: session_id}) do
      delete "/custom_sign_out"
    end
    assert_not Aikotoba::Account::Session.exists?(session_id)
  end

  test "signing out without a session reports nothing" do
    assert_no_event_reported("aikotoba.sign_out") { delete aikotoba.destroy_session_path }
  end
end
