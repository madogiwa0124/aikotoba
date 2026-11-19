# frozen_string_literal: true

require "test_helper"
require "minitest/mock"

class Aikotoba::Account::TwoFactorTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper

  def setup
    @account = Aikotoba::Account.create_by!(attributes: {email: "two_factor_model@example.com", password: "password"})
  end

  # NOTE: The abstract methods a strategy left to Base, as ".name" / "#name". respond_to? can't
  #       tell (Base defines every abstract method), so this asks who defined them.
  def self.unimplemented_methods(klass)
    base = Aikotoba::Account::TwoFactor::Base
    class_methods = base::ABSTRACT_CLASS_METHODS.select { |name| klass.singleton_class.instance_method(name).owner == base.singleton_class }
    instance_methods = base::ABSTRACT_INSTANCE_METHODS.select { |name| klass.instance_method(name).owner == base }
    class_methods.map { |name| ".#{name}" } + instance_methods.map { |name| "##{name}" }
  end

  def set_up_totp!
    totp = Aikotoba::Account::TwoFactor::Totp.new(account: @account)
    credential = totp.enroll!
    assert totp.enable!(ROTP::TOTP.new(credential.secret).at(Time.current - 30))
    credential.reload
  end

  # NOTE: What adding a strategy has to provide, checked for every registered one. Nothing
  #       checks it at boot: STRATEGIES is the engine's own, so this test is where it's caught.
  test "every registered strategy subclasses Base, implements its abstract methods and has a partial" do
    Aikotoba::Account::TwoFactor::STRATEGIES.each do |key, class_name|
      klass = class_name.constantize
      assert_operator klass, :<, Aikotoba::Account::TwoFactor::Base
      assert_empty self.class.unimplemented_methods(klass), "#{class_name} leaves abstract methods to Base"
      assert File.exist?(Aikotoba::Engine.root.join("app/views/aikotoba/two_factors/_#{key}.html.erb")), "missing partial for #{key}"
    end
  end

  class Base < ActiveSupport::TestCase
    # NOTE: A strategy that forgot some of what it has to decide.
    class Incomplete < Aikotoba::Account::TwoFactor::Base
      def start!
      end
    end

    test "the contract check finds what a strategy left to Base" do
      assert_equal %w[.enrollment_required? #usable? #authenticate #challenge_active? #challenge_expiry],
        Aikotoba::Account::TwoFactorTest.unimplemented_methods(Incomplete)
    end

    test "an abstract method left to Base raises when called" do
      assert_raises(NotImplementedError) { Incomplete.enrollment_required? }
      error = assert_raises(NotImplementedError) { Incomplete.new(account: Aikotoba::Account.new).usable? }
      assert_match(/Incomplete must implement #usable\?/, error.message)
    end

    test "authentication_failed! counts a failed sign in and locks the account past the limit" do
      Aikotoba.config.lockable = true
      Aikotoba.config.max_failed_attempts = 1
      account = Aikotoba::Account.create_by!(attributes: {email: "base_strategy@example.com", password: "password"})
      strategy = Incomplete.new(account: account)
      strategy.send(:authentication_failed!)
      assert_not account.locked?
      strategy.send(:authentication_failed!)
      assert account.locked?
      assert account.reload.locked?
      assert_equal 2, account.failed_attempts
    end
  end

  test "account.two_factor is the account's second factor" do
    assert_instance_of Aikotoba::Account::TwoFactor, @account.two_factor
  end

  test "strategy_for picks the first of the scope's strategies the account can use" do
    assert_equal "email_otp", @account.two_factor.strategy_for(%w[totp email_otp])
    assert_nil @account.two_factor.strategy_for(%w[totp])

    set_up_totp!
    assert_equal "totp", @account.two_factor.strategy_for(%i[totp email_otp])
    assert_equal "email_otp", @account.two_factor.strategy_for(%w[email_otp totp])
    assert_equal "email_otp", @account.two_factor.strategy_for(%w[unknown email_otp])
  end

  test "a pending TOTP set up isn't usable yet" do
    Aikotoba::Account::TwoFactor::Totp.new(account: @account).enroll!
    assert_equal "email_otp", @account.two_factor.strategy_for(%w[totp email_otp])
  end

  test "start! challenges the account with the strategy and says which one, and until when" do
    freeze_time do
      challenge = nil
      assert_emails 1 do
        challenge = @account.two_factor.start!(strategy: "email_otp")
      end
      assert_equal "email_otp", challenge.strategy
      assert_equal Aikotoba.email_otp_code_expiry.from_now, challenge.expires_at
    end
    assert_not_nil @account.reload.email_otp_code
  end

  test "start! with TOTP sends nothing and waits totp_challenge_expiry" do
    set_up_totp!
    freeze_time do
      challenge = nil
      assert_no_emails { challenge = @account.two_factor.start!(strategy: "totp") }
      assert_equal Aikotoba.totp_challenge_expiry.from_now, challenge.expires_at
    end
  end

  test "start! raises on an unknown strategy" do
    assert_raises(ArgumentError) { @account.two_factor.start!(strategy: "unknown") }
    assert_raises(ArgumentError) { @account.two_factor.start!(strategy: nil) }
  end

  test "authenticate and challenge_active? go to the strategy that started the challenge" do
    challenge = @account.two_factor.start!(strategy: "email_otp")
    code = @account.reload.email_otp_code.code
    assert @account.two_factor.challenge_active?(strategy: challenge.strategy)
    assert_equal true, @account.two_factor.authenticate(code, strategy: challenge.strategy)
    assert_not @account.two_factor.challenge_active?(strategy: challenge.strategy)
  end

  test "an unknown strategy answers like an expired challenge, and is never constantized" do
    @account.two_factor.start!(strategy: "email_otp")
    code = @account.reload.email_otp_code.code
    %w[unknown Kernel Aikotoba::Account::TwoFactor::EmailOtp].each do |key|
      assert_not Aikotoba::Account::TwoFactor.strategy?(key)
      assert_equal false, @account.two_factor.authenticate(code, strategy: key)
      assert_not @account.two_factor.challenge_active?(strategy: key)
    end
    assert_not_nil @account.reload.email_otp_code
  end

  test "an account of another target type than the scope's can't answer, and nothing is counted" do
    @account.two_factor.start!(strategy: "email_otp")
    code = @account.reload.email_otp_code.code
    assert_equal false, @account.two_factor.authenticate(code, strategy: "email_otp", target_type_name: "Admin")
    assert_not @account.two_factor.challenge_active?(strategy: "email_otp", target_type_name: "Admin")
    assert_not_nil @account.reload.email_otp_code
    assert_equal 0, @account.failed_attempts
  end

  test "an account locked since the challenge can't answer it, even through a record loaded before" do
    Aikotoba.config.lockable = true
    @account.two_factor.start!(strategy: "email_otp")
    code = @account.reload.email_otp_code.code
    loaded_before = Aikotoba::Account.find(@account.id)
    @account.lock!
    assert_equal false, loaded_before.two_factor.authenticate(code, strategy: "email_otp")
    assert_not loaded_before.two_factor.challenge_active?(strategy: "email_otp")
  end

  class ValidateConfiguration < ActiveSupport::TestCase
    def validate!
      Aikotoba::Account::TwoFactor.validate_configuration!(Aikotoba.scopes)
    end

    def offer(strategies)
      Aikotoba.config.default_scope[:two_factor_strategies] = strategies
    end

    def assert_invalid(pattern)
      error = assert_raises(Aikotoba::Errors::InvalidTwoFactorConfiguration) { validate! }
      assert_match pattern, error.message
    end

    test "passes with no scope offering two-factor sign in, or with email_otp" do
      assert_nothing_raised { validate! }
      offer(%w[email_otp])
      assert_nothing_raised { validate! }
    end

    test "rejects an unknown strategy" do
      offer(%w[sms email_otp])
      assert_invalid(/default.two_factor_strategies lists unknown strategies: sms/)
    end

    test "rejects a scope offering only strategies an account has to set up first" do
      offer(%w[totp])
      assert_invalid(/without setting it up first \(email_otp\): .*couldn't sign in to set it up/)
    end

    def warnings_from_validate!
      warnings = []
      logger = Object.new
      logger.define_singleton_method(:warn) { |message| warnings << message }
      Aikotoba.stub(:logger, logger) { assert_nothing_raised { validate! } }
      warnings
    end

    test "TOTP without encrypted_token warns, in any environment" do
      offer(%w[totp email_otp])
      Rails.stub(:env, ActiveSupport::EnvironmentInquirer.new("production")) do
        assert_match(/TOTP is offered \(default\) but encrypted_token is off/, warnings_from_validate!.join)
      end
    end

    test "TOTP with encrypted_token passes quietly" do
      offer(%w[totp email_otp])
      Aikotoba.config.encrypted_token = true
      assert_empty warnings_from_validate!
    end
  end
end
