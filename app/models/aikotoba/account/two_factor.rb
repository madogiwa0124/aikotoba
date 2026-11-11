# frozen_string_literal: true

module Aikotoba
  # NOTE: The one entry point for second factors. Controllers and the sign in helpers talk to
  #       this, never to a concrete method, so adding one (an authenticator app, recovery codes)
  #       means writing its class and registering it in STRATEGIES, with no change to them.
  #
  #       A strategy is a class answering, like Account::EmailOtp:
  #         .start!(account:)                                   # issue a challenge (send a code, ...)
  #         .authenticate_by(account_id:, response:, target_type_name:) # => the account, or nil
  #         .challenge_active?(account_id:, target_type_name:)  # can the challenge still be answered?
  #         .challenge_expiry                                   # how long a sign in may wait on it
  #       It owns its storage, its check and its failed-attempt bookkeeping, as
  #       Account::PasswordHash does for the first factor, and its page has a partial named after
  #       its key (app/views/aikotoba/two_factors/_email_otp.html.erb).
  class Account::TwoFactor
    STRATEGIES = {
      "email_otp" => "Aikotoba::Account::EmailOtp"
    }.freeze

    # NOTE: What a started sign in has to remember (in the Rails session) to finish it: which
    #       strategy challenged it, so the answer goes back to the same one, and until when.
    Challenge = Data.define(:strategy, :expires_at)

    class << self
      # NOTE: The strategy an account signs in with. Only email_otp exists so far; once there
      #       are more, this is where an account's enrolled one (or the scope's) is picked.
      def strategy_for(_account)
        "email_otp"
      end

      def start!(account:)
        key = strategy_for(account)
        strategy = strategy!(key)
        strategy.start!(account: account)
        Challenge.new(strategy: key, expires_at: strategy.challenge_expiry.from_now)
      end

      # NOTE: strategy comes from the Rails session; an unknown one (a session written by
      #       another version, say) answers like an expired challenge rather than raising.
      def authenticate_by(strategy:, account_id:, response:, target_type_name: nil)
        find_strategy(strategy)&.authenticate_by(account_id: account_id, response: response, target_type_name: target_type_name)
      end

      def challenge_active?(strategy:, account_id:, target_type_name: nil)
        find_strategy(strategy)&.challenge_active?(account_id: account_id, target_type_name: target_type_name) || false
      end

      def strategy?(key)
        STRATEGIES.key?(key.to_s)
      end

      private

      # NOTE: Resolved only through STRATEGIES, never by constantizing the key, since the key
      #       is read back from the session.
      def find_strategy(key)
        STRATEGIES[key.to_s]&.constantize
      end

      def strategy!(key)
        find_strategy(key) || raise(ArgumentError, "unknown two factor strategy: #{key.inspect}")
      end
    end
  end
end
