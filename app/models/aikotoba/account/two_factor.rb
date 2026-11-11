# frozen_string_literal: true

module Aikotoba
  # NOTE: An account's second factor, reached as account.two_factor. Controllers and the sign
  #       in helpers talk to this, never to a concrete strategy, so adding one (an
  #       authenticator app, recovery codes) means writing its class and registering it in
  #       STRATEGIES, with no change to them. Account itself only gets the #two_factor reader:
  #       what a second factor does stays here and in the strategies.
  #
  #       A strategy is a class built with new(account:) whose instances answer, like
  #       Account::TwoFactor::EmailOtp:
  #         #start!                                   # issue a challenge (send a code, ...)
  #         #authenticate(response, target_type_name:) # => the account, or nil
  #         #challenge_active?                        # can the challenge still be answered?
  #         #challenge_expiry                         # how long a sign in may wait on it
  #       It owns its storage, its check and its failed-attempt bookkeeping, as
  #       Account::PasswordHash does for the first factor, and its page has a partial named after
  #       its key (app/views/aikotoba/two_factors/_email_otp.html.erb). Whether the account may
  #       still sign in at all is checked here, before any strategy is asked.
  class Account::TwoFactor
    STRATEGIES = {
      "email_otp" => "Aikotoba::Account::TwoFactor::EmailOtp"
    }.freeze

    # NOTE: What a started sign in has to remember (in the Rails session) to finish it: which
    #       strategy challenged it, so the answer goes back to the same one, and until when.
    Challenge = Data.define(:strategy, :expires_at)

    def self.strategy?(key)
      STRATEGIES.key?(key.to_s)
    end

    def initialize(account:)
      @account = account
    end

    # NOTE: The strategy the account signs in with. Only email_otp exists so far; once there
    #       are more, this is where the account's enrolled one (or the scope's) is picked.
    def strategy_key
      "email_otp"
    end

    def start!
      key = strategy_key
      strategy = build_strategy(key) || raise(ArgumentError, "unknown two factor strategy: #{key.inspect}")
      strategy.start!
      Challenge.new(strategy: key, expires_at: strategy.challenge_expiry.from_now)
    end

    # NOTE: strategy is the key the challenge was started with (Challenge#strategy, kept in the
    #       Rails session); an unknown one answers like an expired challenge rather than raising.
    def authenticate(response, strategy:, target_type_name: nil)
      return unless can_sign_in?(target_type_name)

      build_strategy(strategy)&.authenticate(response, target_type_name: target_type_name)
    end

    # NOTE: Whether the sign in can still be finished: the account can still sign in to the
    #       scope, and the strategy's challenge can still be answered. Once not, the sign in has
    #       to start over from the password.
    def challenge_active?(strategy:, target_type_name: nil)
      return false unless can_sign_in?(target_type_name)

      build_strategy(strategy)&.challenge_active? || false
    end

    private

    # NOTE: Asks the database, not the loaded record: the account may have been locked (or
    #       otherwise barred from this scope) since the password step.
    def can_sign_in?(target_type_name)
      Account.authenticatable(target_type_name: target_type_name).exists?(id: @account.id)
    end

    # NOTE: Resolved only through STRATEGIES, never by constantizing the key, since the key
    #       is read back from the session.
    def build_strategy(key)
      STRATEGIES[key.to_s]&.constantize&.new(account: @account)
    end
  end
end
