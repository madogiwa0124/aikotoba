# frozen_string_literal: true

require "test_helper"

# A token request for an email with no account gets the same response as one that has an
# account, so the log line is the only trace of why no email was sent. It leaves the email out,
# since filter_parameters doesn't mask a log message.
class TokenRequestLoggingTest < ActionDispatch::IntegrationTest
  def setup
    ActionController::Base.allow_forgery_protection = false
    @io = StringIO.new
    @original_logger = Rails.logger
    Rails.logger = ActiveSupport::Logger.new(@io)
  end

  def teardown
    Rails.logger = @original_logger
  end

  {
    confirmable: [:create_confirmation_token_path, "[Aikotoba] Confirmation email not sent: no unconfirmed account with that email in the default scope."],
    lockable: [:create_unlock_token_path, "[Aikotoba] Unlock email not sent: no locked account with that email in the default scope."],
    recoverable: [:create_recovery_token_path, "[Aikotoba] Password reset email not sent: no account with that email in the default scope."],
    magic_link_authenticatable: [:create_magic_link_path, "[Aikotoba] Magic link not sent: no account with that email in the default scope."]
  }.each do |feature, (path, line)|
    test "#{path} logs why no email was sent for an unknown email, without the email" do
      Aikotoba.config.public_send(:"#{feature}=", true)
      post aikotoba.public_send(path), params: {account: {email: "unknown@example.com"}}
      assert_response :redirect
      assert_includes @io.string, line
      assert_not_includes @io.string.lines.grep(/\[Aikotoba\]/).join, "unknown@example.com"
    end
  end

  test "a request in another scope names that scope" do
    Aikotoba.config.recoverable = true
    post aikotoba.admin_create_recovery_token_path, params: {account: {email: "unknown@example.com"}}
    assert_includes @io.string, "[Aikotoba] Password reset email not sent: no account with that email in the admin scope."
  end

  test "nothing is logged when the email is sent" do
    Aikotoba.config.recoverable = true
    Aikotoba::Account.create_by!(attributes: {email: "known@example.com", password: "password"})
    post aikotoba.create_recovery_token_path, params: {account: {email: "known@example.com"}}
    assert_no_match(/\[Aikotoba\]/, @io.string)
  end
end
