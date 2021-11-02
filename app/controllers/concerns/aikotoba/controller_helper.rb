module Aikotoba
  module ControllerHelper
    extend ActiveSupport::Concern

    included do
      alias_method "current_#{aikotoba_account_class_prefix}", :aikotoba_current_account
      alias_method "authenticate_#{aikotoba_account_class_prefix}!", :aikotoba_authenticate_account!
      private_class_method :aikotoba_account_class_prefix
    end

    module ClassMethods
      def aikotoba_account_class_prefix
        Aikotoba.authenticate_class.constantize.to_s.gsub("::", "").underscore
      end
    end

    def aikotoba_current_account
      @aikotoba_current_account ||= aikotoba_authenticate_by_session
    end

    def aikotoba_authenticate_account!
      return if aikotoba_current_account
      redirect_to aikotoba.sign_in_path, flash: {alert: aikotoba_required_sign_in_message}
    end

    def aikotoba_sign_in(account)
      session[aikotoba_session_key] = account.id
    end

    def aikotoba_sign_out
      session[aikotoba_session_key] = nil
    end

    def aikotoba_authenticate_by_session
      aikotoba_account_class.find_by(id: session[aikotoba_session_key])
    end

    def aikotoba_account_class
      Aikotoba.authenticate_class.constantize
    end

    private

    def aikotoba_required_sign_in_message
      I18n.t(".aikotoba.messages.authentication.required")
    end

    def aikotoba_session_key
      Aikotoba.session_key
    end
  end
end
