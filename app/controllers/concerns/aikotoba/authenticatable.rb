module Aikotoba
  module Authenticatable
    extend ActiveSupport::Concern
    include Protection::SessionFixationAttack
    include Scopable

    included do
      helper_method :aikotoba_current_account
    end

    def aikotoba_current_account
      @aikotoba_current_account ||= aikotoba_current_session&.account
    end

    def aikotoba_sign_in(account)
      start_new_aikotoba_session_for(account)
    end

    def aikotoba_sign_out
      terminate_aikotoba_session
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
        # NOTE: This is to maintain the session logged in by the old login process, so if you find the account from the session, log in.
        # TODO: Remove this process in future.
        if Aikotoba.keep_legacy_login_session && session[aikotoba_session_key].present?
          account = find_aikotoba_account_by_legacy_session
          account_session = start_new_aikotoba_session_for(account) if account.present?
        end
      end
      account_session
    end

    def find_aikotoba_session_by_cookie
      token = cookies.signed[aikotoba_session_key]
      aikotoba_session_find_by(token) if token.present?
    end

    # NOTE: This is to maintain the session logged in by the old login process, so if you find the account from the session, log in.
    # TODO: Remove this process in future.
    def find_aikotoba_account_by_legacy_session
      aikotoba_authenticatable_accounts.find_by(id: session[aikotoba_session_key])
    end

    def start_new_aikotoba_session_for(account)
      prevent_session_fixation_attack
      @aikotoba_current_session = Aikotoba::Account::Session.start!(account: account, **aikotoba_session_meta_from_request)
      set_aikotoba_session_cookie(@aikotoba_current_session)
      @aikotoba_current_session
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

    def aikotoba_scope_name
      aikotoba_scope_config[:name] || "default"
    end

    def aikotoba_session_meta_from_request
      {
        ip_address: request.remote_ip,
        user_agent: request.user_agent
      }
    end

    # NOTE: Authenticate by target type if specified in the scope configuration.
    # TODO: Remove this process in future.
    def aikotoba_authenticatable_accounts
      Account.authenticatable(target_type_name: aikotoba_authenticate_target)
    end

    def aikotoba_session_find_by(token)
      Account::Session.find_by_token(token, target_type_name: aikotoba_authenticate_target)
    end

    def aikotoba_authenticate_target
      aikotoba_scope_config[:authenticate_for]
    end
  end
end
