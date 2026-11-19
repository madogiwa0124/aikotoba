# frozen_string_literal: true

require "test_helper"
require "minitest/mock"

class Aikotoba::Account::TwoFactorTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper

  # NOTE: A strategy an account has to set up before using it, registered only inside
  #       with_set_up_first, since email_otp (the only one shipped) needs no setting up.
  class SetUpFirst < Aikotoba::Account::TwoFactor::Base
    cattr_accessor :set_up_account_ids, default: []
    cattr_accessor :validated_scope_names

    def self.enrollment_required? = true

    def self.validate_configuration!(scope_names)
      self.validated_scope_names = scope_names
    end

    def usable? = set_up_account_ids.include?(@account.id)

    def start!
    end

    def authenticate(code, target_type_name:) = nil

    def challenge_active? = usable?

    def challenge_expiry = 1.minute
  end

  def self.with_set_up_first(&block)
    two_factor = Aikotoba::Account::TwoFactor
    strategy_class = two_factor.method(:strategy_class)
    strategy = two_factor.method(:strategy?)
    two_factor.stub(:strategy_class, ->(key) { (key.to_s == "set_up_first") ? SetUpFirst : strategy_class.call(key) }) do
      two_factor.stub(:strategy?, ->(key) { key.to_s == "set_up_first" || strategy.call(key) }, &block)
    end
  ensure
    SetUpFirst.set_up_account_ids = []
    SetUpFirst.validated_scope_names = nil
  end

  def with_set_up_first(&block)
    self.class.with_set_up_first(&block)
  end

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
    with_set_up_first do
      assert_equal "email_otp", @account.two_factor.strategy_for(%w[set_up_first email_otp])
      assert_nil @account.two_factor.strategy_for(%w[set_up_first])

      SetUpFirst.set_up_account_ids = [@account.id]
      assert_equal "set_up_first", @account.two_factor.strategy_for(%i[set_up_first email_otp])
      assert_equal "email_otp", @account.two_factor.strategy_for(%w[email_otp set_up_first])
      assert_equal "email_otp", @account.two_factor.strategy_for(%w[unknown email_otp])
    end
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

  test "start! raises on an unknown strategy" do
    assert_raises(ArgumentError) { @account.two_factor.start!(strategy: "unknown") }
    assert_raises(ArgumentError) { @account.two_factor.start!(strategy: nil) }
  end

  test "authenticate and challenge_active? go to the strategy that started the challenge" do
    challenge = @account.two_factor.start!(strategy: "email_otp")
    code = @account.reload.email_otp_code.code
    assert @account.two_factor.challenge_active?(strategy: challenge.strategy)
    assert_equal @account, @account.two_factor.authenticate(code, strategy: challenge.strategy)
    assert_not @account.two_factor.challenge_active?(strategy: challenge.strategy)
  end

  test "an unknown strategy answers like an expired challenge, and is never constantized" do
    @account.two_factor.start!(strategy: "email_otp")
    code = @account.reload.email_otp_code.code
    %w[unknown Kernel Aikotoba::Account::TwoFactor::EmailOtp].each do |key|
      assert_not Aikotoba::Account::TwoFactor.strategy?(key)
      assert_nil @account.two_factor.authenticate(code, strategy: key)
      assert_not @account.two_factor.challenge_active?(strategy: key)
    end
    assert_not_nil @account.reload.email_otp_code
  end

  test "an account of another target type than the scope's can't answer, and nothing is counted" do
    @account.two_factor.start!(strategy: "email_otp")
    code = @account.reload.email_otp_code.code
    assert_nil @account.two_factor.authenticate(code, strategy: "email_otp", target_type_name: "Admin")
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
    assert_nil loaded_before.two_factor.authenticate(code, strategy: "email_otp")
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
      Aikotoba::Account::TwoFactorTest.with_set_up_first do
        offer(%w[set_up_first])
        assert_invalid(/without setting it up first \(email_otp\): .*couldn't sign in to set it up/)
      end
    end

    test "lets each strategy in use check what it needs, with the scopes using it" do
      Aikotoba::Account::TwoFactorTest.with_set_up_first do
        offer(%w[set_up_first email_otp])
        assert_nothing_raised { validate! }
        assert_equal ["default"], SetUpFirst.validated_scope_names
      end
    end
  end
end
