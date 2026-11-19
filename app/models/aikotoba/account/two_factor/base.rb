# frozen_string_literal: true

module Aikotoba
  # NOTE: What every second factor strategy is (see Account::TwoFactor, which picks one and
  #       calls it). A strategy subclasses this, is registered in Account::TwoFactor::STRATEGIES,
  #       and is built with new(account:).
  #
  #       ABSTRACT_CLASS_METHODS and ABSTRACT_INSTANCE_METHODS are what each strategy has to
  #       decide for itself, so they have no default: one left to Base raises NotImplementedError
  #       when called, and Account::TwoFactorTest checks every registered strategy implements
  #       them (respond_to? can't tell, since Base defines them). A default would hide a strategy
  #       that forgot one, e.g. a usable? of true would ask every account for an authenticator
  #       app it never set up.
  #         .enrollment_required?   whether an account has to set it up before using it
  #         #usable?                whether this account can use it now
  #         #start!                 issue a challenge (send a code, or nothing)
  #         #authenticate(code, target_type_name:) the account, or nil (counting the failure)
  #         #challenge_active?      whether the challenge can still be answered
  #         #challenge_expiry       how long a sign in may wait on it
  #       .validate_configuration!(scope_names) is optional: boot-time checks of what the
  #       strategy needs (gems, encryption).
  class Account::TwoFactor::Base
    ABSTRACT_CLASS_METHODS = %i[enrollment_required?].freeze
    ABSTRACT_INSTANCE_METHODS = %i[usable? start! authenticate challenge_active? challenge_expiry].freeze

    class << self
      ABSTRACT_CLASS_METHODS.each do |name|
        define_method(name) { raise NotImplementedError, "#{self} must implement .#{name}" }
      end

      def validate_configuration!(_scope_names)
      end
    end

    def initialize(account:)
      @account = account
    end

    ABSTRACT_INSTANCE_METHODS.each do |name|
      define_method(name) { |*| raise NotImplementedError, "#{self.class} must implement ##{name}" }
    end

    private

    # NOTE: A wrong answer is a failed sign in, like a wrong password: it counts towards
    #       failed_attempts and, with Lockable, locks the account past max_failed_attempts.
    #       Call it inside the strategy's transaction, with @account reloaded under its lock;
    #       @account.locked? tells afterwards whether it locked the account. The same steps as
    #       PasswordHash.authenticate_by's on a wrong password. Named after
    #       Account#authentication_failed!, which it calls and adds Lockable to.
    def authentication_failed!
      @account.authentication_failed!
      Account::Lock.lock!(account: @account, notify: true) if @account.lockable? && @account.should_lock?
    end
  end
end
