# frozen_string_literal: true

module Aikotoba
  # NOTE: An account's second factor, reached as account.two_factor. Controllers and the sign
  #       in helpers talk to this, never to a concrete strategy, so adding one (recovery codes,
  #       ...) means writing its class and registering it in STRATEGIES, with no change to them.
  #       Account itself only gets the #two_factor reader: what a second factor does stays here
  #       and in the strategies.
  #
  #       A strategy subclasses Account::TwoFactor::Base, which lists what it has to implement.
  #       It owns its storage, its check and its failed-attempt bookkeeping, as
  #       Account::PasswordHash does for the first factor, and its page has a partial named
  #       after its key (app/views/aikotoba/two_factors/_email_otp.html.erb). Whether the account
  #       may still sign in at all is checked here, before any strategy is asked.
  class Account::TwoFactor
    STRATEGIES = {
      "email_otp" => "Aikotoba::Account::TwoFactor::EmailOtp"
    }.freeze

    # NOTE: What a started sign in has to remember (in the Rails session) to finish it: which
    #       strategy challenged it, so the answer goes back to the same one, and until when.
    Challenge = Data.define(:strategy, :expires_at)

    class << self
      def strategy?(key)
        STRATEGIES.key?(key.to_s)
      end

      # NOTE: Resolved only through STRATEGIES, never by constantizing the key, since the key
      #       is read back from the session.
      def strategy_class(key)
        STRATEGIES[key.to_s]&.constantize
      end

      # NOTE: Run by the Engine after initialization, once models can be loaded (Scopes#validate!
      #       runs earlier, from the initializer, where they can't). Raises
      #       Errors::InvalidTwoFactorConfiguration for a scope that lists an unknown strategy, or
      #       offers only strategies an account has to set up first (every account of the scope
      #       passes a second factor, and one that hasn't set any up couldn't sign in to do so);
      #       then lets each strategy in use check what it needs. Whether a registered strategy
      #       implements Account::TwoFactor::Base is left to Account::TwoFactorTest: STRATEGIES is
      #       the engine's own, so a strategy can't reach an app without passing that test.
      def validate_configuration!(scopes = Aikotoba.scopes)
        in_use = Hash.new { |hash, key| hash[key] = [] }
        scopes.each do |name, scope|
          next unless scope.two_factor_authenticatable?

          validate_scope!(name, scope)
          scope.two_factor_strategies.each { |key| in_use[key] << name }
        end
        in_use.each { |key, names| strategy_class(key).validate_configuration!(names) }
      end

      private

      def validate_scope!(name, scope)
        unknown = scope.two_factor_strategies.reject { |key| strategy?(key) }
        if unknown.any?
          raise Errors::InvalidTwoFactorConfiguration,
            "#{name}.two_factor_strategies lists unknown strategies: #{unknown.join(", ")}. Known: #{STRATEGIES.keys.join(", ")}."
        end
        if scope.two_factor_strategies.all? { |key| strategy_class(key).enrollment_required? }
          raise Errors::InvalidTwoFactorConfiguration,
            "#{name}.two_factor_strategies needs a strategy accounts can use without setting it up first " \
            "(#{STRATEGIES.keys.reject { |key| strategy_class(key).enrollment_required? }.join(", ")}): " \
            "an account that hasn't set up #{scope.two_factor_strategies.join(" or ")} couldn't sign in to set it up."
        end
      end
    end

    def initialize(account:)
      @account = account
    end

    # NOTE: The strategy the account signs in with: the first of the scope's strategies it can
    #       use (email_otp always; one that needs setting up, once the account has). nil only
    #       when none is usable, which validate_configuration! rules out for a scope that offers
    #       any strategy.
    def strategy_for(strategies)
      strategies.map(&:to_s).find { |key| build_strategy(key)&.usable? }
    end

    def start!(strategy:)
      challenger = build_strategy(strategy) || raise(ArgumentError, "unknown two factor strategy: #{strategy.inspect}")
      challenger.start!
      Challenge.new(strategy: strategy.to_s, expires_at: challenger.challenge_expiry.from_now)
    end

    # NOTE: strategy is the key the challenge was started with (Challenge#strategy, kept in the
    #       Rails session); an unknown one answers like an expired challenge rather than raising.
    def authenticate(code, strategy:, target_type_name: nil)
      return unless can_sign_in?(target_type_name)

      build_strategy(strategy)&.authenticate(code, target_type_name: target_type_name)
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

    def build_strategy(key)
      self.class.strategy_class(key)&.new(account: @account)
    end
  end
end
