module Aikotoba
  module ControllerHelper
    extend ActiveSupport::Concern
    include Aikotoba::Authenticatable
    include Aikotoba::Authorizable

    included do
      alias_method aikotoba_authenticate_account_method_name, :aikotoba_current_account
      alias_method aikotoba_authorize_account_method_name, :aikotoba_authorize
      private_class_method :aikotoba_authenticate_account_method_name, :aikotoba_authorize_account_method_name
    end

    module ClassMethods
      def aikotoba_authenticate_account_method_name
        Aikotoba.authenticate_account_method
      end

      def aikotoba_authorize_account_method_name
        Aikotoba.authorize_account_method
      end
    end

    def aikotoba_current_account
      @aikotoba_current_account ||= aikotoba_authenticate_by_session
    end

    def aikotoba_authorize
      super(aikotoba_current_account)
    end

    def aikotoba_sign_out
      @aikotoba_current_account = nil
      super
    end

    def aikotoba_account_class
      Aikotoba.authenticate_class.constantize
    end

    def aikotoba_session_key
      Aikotoba.session_key
    end
  end
end
