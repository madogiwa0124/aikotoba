# frozen_string_literal: true

module Aikotoba
  # NOTE: A sign in waiting on its second factor (an Account::TwoFactor::Challenge and whose it
  #       is), as kept in the Rails session: which account passed the password, which strategy
  #       challenged it, and until when. The one place that knows that shape, so writing it
  #       (aikotoba_begin_sign_in) and reading it (TwoFactorsController, or an app's own code
  #       page) can't disagree.
  #
  #       Made for the Rails session, passed in as session: so callers see where the state
  #       lives: it is bound to the browser that entered the password, and stored wherever the
  #       app's session_store keeps sessions (the cookie by default; :cache_store and the like
  #       keep it on the server). Taken from the controller rather than reached for through
  #       the request.
  #
  #       Only that much goes in the session. What the strategy checks (a code and the
  #       attempts made against it, ...) stays in the database with the strategy, since a
  #       cookie session can be replayed to undo an attempt count or reuse a code.
  #
  #       Build one per use rather than keeping it: reset_session (session fixation
  #       protection) replaces the session object it would hold.
  class Account::TwoFactor::ChallengeStore
    def initialize(session:, key:)
      @session = session
      @key = key
    end

    def start(account, challenge)
      @session[@key] = {
        "account_id" => account.id,
        "strategy" => challenge.strategy,
        "expires_at" => challenge.expires_at.to_i
      }
    end

    # NOTE: Whether a sign in has been waiting here, whether or not it can still be finished:
    #       tells "never started" (the page opened directly) from "started, but expired" apart.
    def started?
      @session.key?(@key)
    end

    # NOTE: {"account_id" => ..., "strategy" => ...} while a sign in can still be finished,
    #       else nil (none started, expired, or written for a strategy that no longer exists).
    #       Only reads: clearing one that can't be finished is the caller's call (#clear).
    def current
      pending = @session[@key]
      return unless pending.is_a?(Hash)
      return if expired?(pending) || !known_strategy?(pending)

      pending.slice("account_id", "strategy")
    end

    # NOTE: Clear it before aikotoba_sign_in: its session fixation protection copies every
    #       value of the old session into the new one.
    def clear
      @session.delete(@key)
    end

    private

    def expired?(pending)
      Time.current.to_i > pending["expires_at"].to_i
    end

    # NOTE: A session can outlive a strategy being removed from Account::TwoFactor::STRATEGIES.
    def known_strategy?(pending)
      Account::TwoFactor.strategy?(pending["strategy"])
    end
  end
end
