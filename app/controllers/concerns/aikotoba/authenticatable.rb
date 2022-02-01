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

    def aikotoba_authenticate_by_session
      Account.find_by(id: session[aikotoba_session_key])
    end

    private

    def aikotoba_session_key
      Aikotoba.session_key
    end
  end
end
