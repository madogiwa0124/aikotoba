module Aikotoba
  module Authenticatable
    extend ActiveSupport::Concern
    include Protection::SessionFixationAttack
    include Scopable

    included do
      helper_method :aikotoba_current_account
    end

    def aikotoba_current_account
      unless defined?(@aikotoba_current_account)
        @aikotoba_current_account ||= aikotoba_authenticate_by_session
      end
      @aikotoba_current_account
    end

    def aikotoba_sign_in(account)
      prevent_session_fixation_attack
      session[aikotoba_session_key] = account.id
    end

    # TODO: Currently, all sessions are reset, but ideally, it should consider the namespace.
    def aikotoba_sign_out
      @aikotoba_current_account = nil
      reset_session
    end

    private

    # NOTE: Even if there is already a session, verify that it can be authenticated, and if not, reset the session,
    # in case the session is created and then locked by another browser etc.
    def aikotoba_authenticate_by_session
      account = aikotoba_authenticatable_accounts.find_by(id: session[aikotoba_session_key])
      account.tap { |account| reset_aikotoba_session unless account }
    end

    # NOTE: Authenticate by target type if specified in the scope configuration.
    def aikotoba_authenticatable_accounts
      Account.authenticatable(target_type_name: aikotoba_authenticate_target)
    end

    def reset_aikotoba_session
      session[aikotoba_session_key] = nil
    end

    def aikotoba_session_key
      aikotoba_scope_config[:session_key]
    end

    def aikotoba_authenticate_target
      aikotoba_scope_config[:authenticate_for]
    end
  end
end
