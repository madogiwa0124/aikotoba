module Aikotoba
  module Authenticatable
    extend ActiveSupport::Concern
    include Protection::TimingAtack
    include Protection::SessionFixationAttack

    def aikotoba_sign_in(account)
      prevent_session_fixation_attack
      session[aikotoba_session_key] = account.id
    end

    def aikotoba_sign_out
      reset_session
    end

    def aikotoba_authenticate_by_session
      prevent_timing_atack
      aikotoba_account_class.find_by(id: session[aikotoba_session_key])
    end

    private

    def aikotoba_account_class
      raise NotImplementedError
    end

    def aikotoba_session_key
      raise NotImplementedError
    end
  end
end
