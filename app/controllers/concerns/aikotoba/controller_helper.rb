module Aikotoba
  module ControllerHelper
    extend ActiveSupport::Concern

    included do
      alias_method "current_#{account_class_prefix}", :current_account
      alias_method "authenticate_#{account_class_prefix}!", :authenticate_account!
    end

    module ClassMethods
      def account_class_prefix
        Aikotoba.authenticate_class.constantize.to_s.gsub("::", "").underscore
      end
    end

    def current_account
      @current_account ||= authenticate_by_session
    end

    def authenticate_account!
      return if current_account
      redirect_to sign_in_path, flash: {alert: required_sign_in_message}
    end

    def sign_in(account)
      session[session_key] = account.id
    end

    def sign_out
      session[session_key] = nil
    end

    def authenticate_by_session
      account_class.find_by(id: session[session_key])
    end

    def required_sign_in_message
      I18n.t(".aikotoba.authentication.required")
    end

    def session_key
      Aikotoba.session_key
    end

    def account_class
      Aikotoba.authenticate_class.constantize
    end
  end
end
