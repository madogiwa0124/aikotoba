# frozen_string_literal: true

module Aikotoba
  module Api
    class RefreshTokensController < ApplicationController
      include Api::Authenticatable

      def create
        before_refresh_process
        account_session = account_api_session_refresh!(refresh_token_param)
        if account_session
          after_refresh_process
          render json: aikotoba_api_token_payload(account_session).to_h, status: :ok
        else
          failed_refresh_process
          refresh_failed_error_response(refresh_failed_message)
        end
      end

      private

      def refresh_failed_error_response(message)
        render_from_api_error(Api::Error.unauthorized(detail: message))
      end

      def account_api_session_refresh!(refresh_token_value)
        Account::RefreshToken.refresh_session!(
          refresh_token_value: refresh_token_value,
          origin: :api,
          **aikotoba_api_session_meta_from_request
        )
      end

      def refresh_failed_message
        t("aikotoba.api.messages.refresh.failed")
      end

      def refresh_token_param
        params.permit(:refresh_token).require(:refresh_token)
      end

      # NOTE: Methods to override if you want to do something before refresh.
      def before_refresh_process
      end

      # NOTE: Methods to override if you want to do something after refresh.
      def after_refresh_process
      end

      # NOTE: Methods to override if you want to do something failed refresh.
      def failed_refresh_process
      end
    end
  end
end
