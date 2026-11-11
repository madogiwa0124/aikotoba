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

    def aikotoba_sign_in(account)
      start_new_aikotoba_session_for(account).tap do |session|
        Event::SignIn.report(**session.event_payload, scope: aikotoba_scope.to_s)
      end
    end

    # NOTE: What to call once the first factor (a password) has been checked: signs in right
    #       away (and returns the session, as aikotoba_sign_in does) unless the scope requires
    #       a second factor, in which case it sends a one-time code and returns nil, leaving
    #       the account to finish at the scope's two_factor_path. No Account::Session exists
    #       until then, so aikotoba_current_account stays nil in between.
    #       An app's own sign in controller calls this rather than aikotoba_sign_in, and
    #       passes reset_failed_attempts: !aikotoba_two_factor_required? to
    #       Account::PasswordHash.authenticate_by (see there).
    def aikotoba_begin_sign_in(account)
      return aikotoba_sign_in(account) unless aikotoba_two_factor_required?

      start_aikotoba_two_factor_for(account)
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

    # NOTE: The sign in in progress lives in the Rails session: which account passed the
    #       password, and until when. The code itself and the attempts made against it are
    #       kept in the database (Account::EmailOtpCode), since a cookie session can be
    #       replayed to undo an attempt count or reuse a code.
    #       The session is reset first, so a session fixed before the password step can't
    #       inherit the sign in in progress.
    def start_aikotoba_two_factor_for(account)
      prevent_session_fixation_attack
      Account::EmailOtp.create_code!(account: account, notify: true)
      session[aikotoba_two_factor_session_key] = {
        "account_id" => account.id,
        "expires_at" => Aikotoba.email_otp_code_expiry.from_now.to_i
      }
    end

    def aikotoba_two_factor_account_id
      pending = session[aikotoba_two_factor_session_key]
      return unless pending.is_a?(Hash)

      if Time.current.to_i > pending["expires_at"].to_i
        clear_aikotoba_two_factor
        return
      end
      pending["account_id"]
    end

    # NOTE: Has to run before aikotoba_sign_in: its session fixation protection copies every
    #       value of the old session into the new one.
    def clear_aikotoba_two_factor
      session.delete(aikotoba_two_factor_session_key)
    end

    def aikotoba_two_factor_session_key
      "#{aikotoba_session_key}_two_factor"
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
