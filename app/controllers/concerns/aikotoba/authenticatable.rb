module Aikotoba
  module Authenticatable
    extend ActiveSupport::Concern
    include Protection::SessionFixationAttack
    include Scopable
    include RequestBackable

    included do
      helper_method :aikotoba_current_account
    end

    def aikotoba_current_account
      @aikotoba_current_account ||= aikotoba_current_session&.account
    end

    TWO_FACTOR_SIGN_IN_REASONS = %i[verified skip].freeze

    # NOTE: Starts a session right away, whatever the scope requires. In a scope with
    #       two_factor_authenticatable, the caller has to say why that is fine: :verified once
    #       the account passed its second factor, :skip when the credential needs none (a
    #       magic link already proves the mailbox). Without it this raises
    #       Errors::TwoFactorRequired before signing in, so a controller that should have
    #       called aikotoba_begin_sign_in fails the first time it runs rather than skipping
    #       the second factor. Scopes without two_factor_authenticatable ignore two_factor:.
    def aikotoba_sign_in(account, two_factor: nil)
      unless two_factor.nil? || TWO_FACTOR_SIGN_IN_REASONS.include?(two_factor)
        raise ArgumentError, "two_factor: must be one of #{TWO_FACTOR_SIGN_IN_REASONS.inspect}, got #{two_factor.inspect}"
      end
      if two_factor.nil? && aikotoba_two_factor_required?
        raise Errors::TwoFactorRequired,
          "the #{aikotoba_scope} scope requires a second factor: call aikotoba_begin_sign_in after checking " \
          "the password, or pass two_factor: :verified (it was passed) or :skip (none is needed) to aikotoba_sign_in"
      end

      start_new_aikotoba_session_for(account).tap do |session|
        Event::SignIn.report(**session.event_payload, scope: aikotoba_scope.to_s)
      end
    end

    # NOTE: What to call once the first factor (a password) has been checked: signs in right
    #       away (and returns the session, as aikotoba_sign_in does) unless the scope requires
    #       a second factor, in which case it sends a one-time code and returns nil, leaving
    #       the account to finish at the scope's two_factor_path. No Account::Session exists
    #       until then, so aikotoba_current_account stays nil in between.
    #       An app's own sign in controller calls this rather than aikotoba_sign_in.
    #       The session is reset first, so a session fixed before the password step can't
    #       inherit the sign in in progress. Which strategy, and how it challenges, is
    #       account.two_factor's (Account::TwoFactor) to decide.
    def aikotoba_begin_sign_in(account)
      return aikotoba_sign_in(account) unless aikotoba_two_factor_required?

      prevent_session_fixation_attack
      challenge = account.two_factor.start!
      aikotoba_two_factor_challenge_store.start(account, challenge)
      nil
    end

    def aikotoba_two_factor_required?
      aikotoba_scope_config.two_factor_authenticatable?
    end

    # NOTE: Loads the session from the cookie when nothing has read it yet, so the session is
    #       revoked (and sign_out reported) however early an app's own action calls this.
    def aikotoba_sign_out
      session = aikotoba_current_session
      terminate_aikotoba_session
      Event::SignOut.report(**session.event_payload, scope: aikotoba_scope.to_s) if session
    end

    private

    def aikotoba_current_session
      unless defined?(@aikotoba_current_session)
        @aikotoba_current_session ||= resume_aikotoba_session
      end
      @aikotoba_current_session
    end

    def resume_aikotoba_session
      account_session = find_aikotoba_session_by_cookie
      unless account_session
        # NOTE: NOTE: Even if there is already a session, verify that it can be authenticated, and if not, reset the session,
        # in case the session is created and then locked by another browser etc.
        #
        # Although the session record in DB should be deleted ideally,
        # deleting it issues a DELETE statement that causes an error due to Rails' multi-DB automatic switching feature,
        # so the session record deletion is not performed here.
        # Deleting only the cookie will require explicit re-login, and the situation where only the DB session remains can also occur
        # when the cookie is directly deleted on the browser side, so we decided to allow it.
        terminate_aikotoba_session(only_cookie: true)
      end
      account_session
    end

    def find_aikotoba_session_by_cookie
      token = cookies.signed[aikotoba_session_key]
      aikotoba_session_find_by(token) if token.present?
    end

    def start_new_aikotoba_session_for(account)
      prevent_session_fixation_attack
      @aikotoba_current_session = Aikotoba::Account::Session.start!(account: account, **aikotoba_session_meta_from_request)
      set_aikotoba_session_cookie(@aikotoba_current_session)
      @aikotoba_current_session
    end

    # NOTE: The sign in waiting on its second factor (see Account::TwoFactor::ChallengeStore). The one
    #       two-factor method this concern adds to every controller including it; built anew
    #       on each call, since reset_session replaces the session.
    def aikotoba_two_factor_challenge_store
      Account::TwoFactor::ChallengeStore.new(session: session, key: "#{aikotoba_session_key}_two_factor")
    end

    def terminate_aikotoba_session(only_cookie: false)
      # NOTE: If you call `aikotoba_current_session` method, `aikotoba_current_session` will be regenerated, so refer to the instance variable directly.
      @aikotoba_current_session&.revoke! unless only_cookie
      cookies.delete(aikotoba_session_key)
      @aikotoba_current_session = nil
      @aikotoba_current_account = nil
    end

    def set_aikotoba_session_cookie(account_session)
      cookies.signed[aikotoba_session_key] = {
        value: account_session.token,
        httponly: true,
        same_site: :lax,
        # NOTE: Set the secure attribute except in the development and test environment
        secure: !Rails.env.local?,
        expires: Aikotoba.session_expiry.from_now
      }
    end

    def aikotoba_session_key
      aikotoba_scope_config[:session_key]
    end

    def aikotoba_session_meta_from_request
      {
        ip_address: request.remote_ip,
        user_agent: request.user_agent
      }
    end

    def aikotoba_session_find_by(token)
      Account::Session.find_by_token(token, target_type_name: aikotoba_authenticate_target)
    end
  end
end
