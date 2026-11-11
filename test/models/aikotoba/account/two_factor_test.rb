# frozen_string_literal: true

require "test_helper"
require "minitest/mock"

class Aikotoba::Account::TwoFactorTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper

  def setup
    @account = Aikotoba::Account.create_by!(attributes: {email: "two_factor_model@example.com", password: "password"})
  end

  # NOTE: What adding a strategy has to provide, checked for every registered one.
  test "every registered strategy implements the interface and has a partial" do
    Aikotoba::Account::TwoFactor::STRATEGIES.each do |key, class_name|
      strategy = class_name.constantize
      %i[start! authenticate_by challenge_active? challenge_expiry].each do |method|
        assert_respond_to strategy, method, "#{class_name} must implement .#{method}"
      end
      assert_equal %i[account_id response target_type_name], strategy.method(:authenticate_by).parameters.map(&:last).sort
      assert File.exist?(Aikotoba::Engine.root.join("app/views/aikotoba/two_factors/_#{key}.html.erb")), "missing partial for #{key}"
    end
  end

  test "start! challenges the account with its strategy and says which one, and until when" do
    freeze_time do
      challenge = nil
      assert_emails 1 do
        challenge = Aikotoba::Account::TwoFactor.start!(account: @account)
      end
      assert_equal "email_otp", challenge.strategy
      assert_equal Aikotoba.email_otp_code_expiry.from_now, challenge.expires_at
    end
    assert_not_nil @account.reload.email_otp_code
  end

  test "authenticate_by and challenge_active? go to the strategy that started the challenge" do
    challenge = Aikotoba::Account::TwoFactor.start!(account: @account)
    code = @account.reload.email_otp_code.code
    assert Aikotoba::Account::TwoFactor.challenge_active?(strategy: challenge.strategy, account_id: @account.id)
    assert_equal @account, Aikotoba::Account::TwoFactor.authenticate_by(strategy: challenge.strategy, account_id: @account.id, response: code)
    assert_not Aikotoba::Account::TwoFactor.challenge_active?(strategy: challenge.strategy, account_id: @account.id)
  end

  test "an unknown strategy answers like an expired challenge, and is never constantized" do
    Aikotoba::Account::TwoFactor.start!(account: @account)
    code = @account.reload.email_otp_code.code
    %w[unknown Kernel Aikotoba::Account::EmailOtp].each do |key|
      assert_not Aikotoba::Account::TwoFactor.strategy?(key)
      assert_nil Aikotoba::Account::TwoFactor.authenticate_by(strategy: key, account_id: @account.id, response: code)
      assert_not Aikotoba::Account::TwoFactor.challenge_active?(strategy: key, account_id: @account.id)
    end
    assert_not_nil @account.reload.email_otp_code
  end
end
