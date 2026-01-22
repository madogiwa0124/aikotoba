# frozen_string_literal: true

require "test_helper"

class RateLimitTest < ActionDispatch::SystemTestCase
  driven_by :rack_test
  include Aikotoba::Protection::RateLimiting

  def setup
    skip unless self.class.available_rails_rate_limiting?
    Aikotoba.confirmable = true
    Aikotoba.lockable = true
    Aikotoba.recoverable = true
    Aikotoba.confirmation_rate_limit_options = {to: 3, within: 1.minute, by: -> { request.params.dig(:account, :email).presence }, only: :create}
    Aikotoba.unlock_rate_limit_options = {to: 3, within: 1.minute, by: -> { request.params.dig(:account, :email).presence }, only: :create}
    Aikotoba.recovery_rate_limit_options = {to: 3, within: 1.minute, by: -> { request.params.dig(:account, :email).presence }, only: :create}
    # Reload controllers to pick up new rate limit settings
    reload_controllers_with_rate_limit
    # Clear cache before each test to reset rate limit counters
    Rails.cache.clear
  end

  def teardown
    Aikotoba.confirmable = false
    Aikotoba.lockable = false
    Aikotoba.recoverable = false
    Aikotoba.confirmation_rate_limit_options = {}
    Aikotoba.unlock_rate_limit_options = {}
    Aikotoba.recovery_rate_limit_options = {}
    reload_controllers_with_rate_limit
    Rails.cache.clear
  end

  private

  # NOTE: rate_limit is evaluated at the time of Class definition,
  #       so it is necessary to explicitly reload the Controller after changing the settings
  def reload_controllers_with_rate_limit
    # Remove existing controller constants to force reload
    Aikotoba.send(:remove_const, :ConfirmsController) if Aikotoba.const_defined?(:ConfirmsController)
    Aikotoba.send(:remove_const, :UnlocksController) if Aikotoba.const_defined?(:UnlocksController)
    Aikotoba.send(:remove_const, :RecoveriesController) if Aikotoba.const_defined?(:RecoveriesController)

    # Reload controller files with new configuration
    load Rails.root.join("../../app/controllers/aikotoba/confirms_controller.rb")
    load Rails.root.join("../../app/controllers/aikotoba/unlocks_controller.rb")
    load Rails.root.join("../../app/controllers/aikotoba/recoveries_controller.rb")
  end

  test "confirm endpoint is rate limited to 3 requests per minute per email" do
    email = "test@example.com"

    # Make 4 rapid requests to confirm endpoint
    responses = []
    4.times do |i|
      visit "/confirm"
      fill_in "Email", with: email
      click_on "Send confirm token"
      # Check if we got throttled (429 response) or success message
      responses << (has_text?("Too many requests") ? 429 : 200)
    end

    # First 3 should succeed, 4th should be throttled
    assert_equal [200, 200, 200, 429], responses, "Expected 3 success then 1 throttle"
  end

  test "unlock endpoint is rate limited to 3 requests per minute per email" do
    email = "test@example.com"

    responses = []
    4.times do
      visit "/unlock"
      fill_in "Email", with: email
      click_on "Send unlock token"
      responses << (has_text?("Too many requests") ? 429 : 200)
    end

    assert_equal [200, 200, 200, 429], responses
  end

  test "recover endpoint is rate limited to 3 requests per minute per email" do
    email = "test@example.com"

    responses = []
    4.times do
      visit "/recover"
      fill_in "Email", with: email
      click_on "Send password reset token"
      responses << (has_text?("Too many requests") ? 429 : 200)
    end

    assert_equal [200, 200, 200, 429], responses
  end

  test "rate limit is per email address - different emails are counted separately" do
    email1 = "user1@example.com"
    email2 = "user2@example.com"

    # Max out email1
    3.times do
      visit "/confirm"
      fill_in "Email", with: email1
      click_on "Send confirm token"
      assert has_text?("Confirm url has been sent"), "Request for email1 should succeed"
    end

    # 4th request for email1 should be throttled
    visit "/confirm"
    fill_in "Email", with: email1
    click_on "Send confirm token"
    assert has_text?("Too many requests"), "4th request for email1 should be throttled"

    # email2 should not be affected
    visit "/confirm"
    fill_in "Email", with: email2
    click_on "Send confirm token"
    assert has_text?("Confirm url has been sent"), "email2 should not be throttled"
  end

  test "endpoints have separate rate limits" do
    email = "test@example.com"

    # Max out confirm
    3.times do
      visit "/confirm"
      fill_in "Email", with: email
      click_on "Send confirm token"
    end

    # confirm should be throttled
    visit "/confirm"
    fill_in "Email", with: email
    click_on "Send confirm token"
    assert has_text?("Too many requests"), "confirm should be throttled"

    # But unlock should have its own separate counter
    visit "/unlock"
    fill_in "Email", with: email
    click_on "Send unlock token"
    assert has_text?("Unlock url has been sent"), "unlock should not be throttled (separate limit)"
  end
end
