# frozen_string_literal: true

require "test_helper"

class Aikotoba::Account::TwoFactorTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper

  def setup
    @account = Aikotoba::Account.create_by!(attributes: {email: "two_factor_model@example.com", password: "password"})
  end

  def start_and_read_code
    challenge = @account.two_factor.start!
    [challenge, @account.reload.email_otp_code.code]
  end

  # NOTE: What adding a strategy has to provide, checked for every registered one.
  test "every registered strategy implements the interface and has a partial" do
    Aikotoba::Account::TwoFactor::STRATEGIES.each do |key, class_name|
      strategy = class_name.constantize.new(account: @account)
      %i[start! authenticate challenge_active? challenge_expiry].each do |method|
        assert_respond_to strategy, method, "#{class_name} must implement ##{method}"
      end
      assert_equal [[:req, :response], [:key, :target_type_name]], strategy.method(:authenticate).parameters
      assert File.exist?(Aikotoba::Engine.root.join("app/views/aikotoba/two_factors/_#{key}.html.erb")), "missing partial for #{key}"
    end
  end

  test "account.two_factor is the account's second factor" do
    assert_instance_of Aikotoba::Account::TwoFactor, @account.two_factor
    assert_equal "email_otp", @account.two_factor.strategy_key
  end

  test "start! challenges the account with its strategy and says which one, and until when" do
    freeze_time do
      challenge = nil
      assert_emails 1 do
        challenge = @account.two_factor.start!
      end
      assert_equal "email_otp", challenge.strategy
      assert_equal Aikotoba.email_otp_code_expiry.from_now, challenge.expires_at
    end
    assert_not_nil @account.reload.email_otp_code
  end

  test "authenticate and challenge_active? go to the strategy that started the challenge" do
    challenge, code = start_and_read_code
    assert @account.two_factor.challenge_active?(strategy: challenge.strategy)
    assert_equal @account, @account.two_factor.authenticate(code, strategy: challenge.strategy)
    assert_not @account.two_factor.challenge_active?(strategy: challenge.strategy)
  end

  test "an unknown strategy answers like an expired challenge, and is never constantized" do
    _, code = start_and_read_code
    %w[unknown Kernel Aikotoba::Account::TwoFactor::EmailOtp].each do |key|
      assert_not Aikotoba::Account::TwoFactor.strategy?(key)
      assert_nil @account.two_factor.authenticate(code, strategy: key)
      assert_not @account.two_factor.challenge_active?(strategy: key)
    end
    assert_not_nil @account.reload.email_otp_code
  end

  test "an account of another target type than the scope's can't answer, and nothing is counted" do
    challenge, code = start_and_read_code
    assert_nil @account.two_factor.authenticate(code, strategy: challenge.strategy, target_type_name: "Admin")
    assert_not @account.two_factor.challenge_active?(strategy: challenge.strategy, target_type_name: "Admin")
    assert_not_nil @account.reload.email_otp_code
    assert_equal 0, @account.failed_attempts
  end

  test "an account locked since the challenge can't answer it, even through a record loaded before" do
    Aikotoba.config.lockable = true
    challenge, code = start_and_read_code
    loaded_before = Aikotoba::Account.find(@account.id)
    @account.lock!
    assert_nil loaded_before.two_factor.authenticate(code, strategy: challenge.strategy)
    assert_not loaded_before.two_factor.challenge_active?(strategy: challenge.strategy)
  end
end
