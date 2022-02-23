module Aikotoba
  module Authenticatable
    extend ActiveSupport::Concern
    include Protection::SessionFixationAttack

    def aikotoba_current_account
      @aikotoba_current_account ||= aikotoba_authenticate_by_session
    end

    def aikotoba_sign_in(account)
      prevent_session_fixation_attack
      session[aikotoba_session_key] = account.id
    end

    def aikotoba_sign_out
      @aikotoba_current_account = nil
      reset_session
    end

    # NOTE: Even if there is already a session, verify that it can be authenticated, and if not, reset the session,
    # in case the session is created and then locked by another browser etc.
    def aikotoba_authenticate_by_session
      account = Account.authenticatable.find_by(id: session[aikotoba_session_key])
      account.tap { |account| reset_aikotoba_session unless account }
    end

    private

    def reset_aikotoba_session
      session[aikotoba_session_key] = nil
    end

    def aikotoba_session_key
      Aikotoba.session_key
    end
  end
end
