# frozen_string_literal: true

module Aikotoba
  module Api
    module Authenticatable
      extend ActiveSupport::Concern
      include Scopable

      def aikotoba_api_current_account
        @aikotoba_api_current_account ||= aikotoba_api_current_session&.account
      end

      def aikotoba_api_sign_in(account)
        start_new_aikotoba_api_session_for(account)
      end

      def aikotoba_api_sign_out
        aikotoba_api_current_session&.revoke!
      end

      def aikotoba_api_token_payload(account_session)
        Api::Token.new(
          access_token: account_session.token,
          refresh_token: account_session.refresh_token.token,
          expired_at: account_session.expired_at
        )
      end

      private

      def aikotoba_api_current_session
        return @aikotoba_api_current_session if defined?(@aikotoba_api_current_session)

        token = aikotoba_bearer_token
        @aikotoba_api_current_session = if token.present?
          Account::Session.find_by_token(token, target_type_name: aikotoba_authenticate_target, origin: :api)
        end
      end

      def aikotoba_bearer_token
        auth_header = request.headers["Authorization"].to_s
        return if auth_header.blank?

        scheme, token = auth_header.split(" ", 2)
        return unless scheme&.casecmp("Bearer")&.zero?

        token&.strip
      end

      def start_new_aikotoba_api_session_for(account)
        Account::Session.start!(
          account: account,
          origin: :api,
          **aikotoba_api_session_meta_from_request
        )
      end

      def aikotoba_api_session_meta_from_request
        {
          ip_address: request.remote_ip,
          user_agent: request.user_agent
        }
      end

      def aikotoba_authenticate_target
        aikotoba_scope_config[:authenticate_for]
      end
    end
  end
end
