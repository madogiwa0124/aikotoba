module Aikotoba
  module Authorizable
    extend ActiveSupport::Concern

    def aikotoba_authorize(current_account)
      path, message = nil
      path, message = aikotoba_require_sign_in if !current_account
      redirect_to path, flash: {alert: message} if path && message
    end

    private

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
