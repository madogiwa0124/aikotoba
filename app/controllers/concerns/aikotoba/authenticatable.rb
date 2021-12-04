module Aikotoba
  module Authenticatable
    extend ActiveSupport::Concern
    include Protection::TimingAtack
    include Protection::SessionFixationAttack

    included do
      alias_method aikotoba_authenticate_account_method_name, :aikotoba_current_account
      private_class_method :aikotoba_authenticate_account_method_name
    end

    module ClassMethods
      def aikotoba_authenticate_account_method_name
        Aikotoba.authenticate_account_method
      end
    end

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
      prevent_timing_atack
      aikotoba_account_class.find_by(id: session[aikotoba_session_key])
    end

    private

    def aikotoba_account_class
      Aikotoba.authenticate_class.constantize
    end

    def aikotoba_session_key
      Aikotoba.session_key
    end
  end
end
