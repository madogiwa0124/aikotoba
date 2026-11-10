# frozen_string_literal: true

require "test_helper"

# The README's Events example runs in the dummy app (config/initializers/aikotoba_events.rb):
# each aikotoba.* event, and only those, is enqueued as an AuthEventJob with its name, payload
# and context, which Active Job has to serialize.
class EventsSubscriberTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  def setup
    ActionController::Base.allow_forgery_protection = false
    @account = Aikotoba::Account.create_by!(attributes: {email: "email@example.com", password: "password"})
    clear_enqueued_jobs
  end

  def auth_event_jobs
    enqueued_jobs.select { |job| job["job_class"] == "AuthEventJob" }
  end

  test "an event that waits for commit is enqueued with its payload once committed" do
    post aikotoba.create_session_path, params: {account: {email: @account.email, password: "password"}}
    session = Aikotoba::Account::Session.last
    assert_enqueued_with(job: AuthEventJob, args: ["aikotoba.sign_in", {account_id: @account.id, session_id: session.id, scope: "default"}, {}])
  end

  test "a failed attempt is enqueued too, nil values included" do
    post aikotoba.create_session_path, params: {account: {email: "unknown@example.com", password: "password"}}
    assert_enqueued_with(job: AuthEventJob, args: ["aikotoba.sign_in_failed", {email: "unknown@example.com", account_id: nil, target_type_name: nil}, {}])
  end

  test "the context set by the app is passed along" do
    Rails.event.set_context(request_id: "abc")
    Aikotoba::Account::Lock.unlock!(account: @account)
    assert_enqueued_with(job: AuthEventJob, args: ["aikotoba.account_unlocked", {account_id: @account.id}, {request_id: "abc"}])
  ensure
    Rails.event.clear_context
  end

  test "Rails' own events are not enqueued" do
    get aikotoba.new_session_path
    assert_empty auth_event_jobs
  end
end
