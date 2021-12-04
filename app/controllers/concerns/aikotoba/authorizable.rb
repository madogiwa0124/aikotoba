module Aikotoba
  module Authorizable
    extend ActiveSupport::Concern

    included do
      alias_method aikotoba_authorize_account_method_name, :aikotoba_authorize
      private_class_method :aikotoba_authorize_account_method_name
    end

    module ClassMethods
      def aikotoba_authorize_account_method_name
        Aikotoba.authorize_account_method
      end
    end

    def aikotoba_authorize
      path, message = nil
      path, message = aikotoba_require_sign_in if !aikotoba_current_account
      redirect_to path, flash: {alert: message} if path && message
    end

    private

    def aikotoba_current_account
      raise NotImplementedError, "`Aikotoba::Authorizable` depends on `aikotoba_current_account` and should be included before `Aikotoba::Authenticatable``."
    end

    def aikotoba_require_sign_in
      [aikotoba_require_sign_in_path, aikotoba_require_sign_in_message]
    end

    def aikotoba_require_sign_in_path
      Aikotoba.appeal_sign_in_path
    end

    def aikotoba_require_sign_in_message
      I18n.t(".aikotoba.messages.authentication.required")
    end
  end
end
