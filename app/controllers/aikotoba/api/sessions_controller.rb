# frozen_string_literal: true

module Aikotoba
  module Api
    class SessionsController < ApplicationController
      include Api::Authenticatable

      def create
        account = authenticate_account(session_params)
        if account
          before_sign_in_process
          account_session = aikotoba_api_sign_in(account)
          after_sign_in_process
          render json: aikotoba_api_token_payload(account_session).to_h, status: :ok
        else
          failed_sign_in_process
          authentication_failed_error_response(authentication_failed_message)
        end
      end

      def destroy
        aikotoba_api_sign_out if aikotoba_api_current_account
        head :no_content
      end

      private

      def authentication_failed_error_response(message)
        render_from_api_error(Api::Error.unauthorized(detail: message))
      end

      def authenticate_account(params)
        Account.authenticate_by(attributes: params, target_type_name: aikotoba_authenticate_target)
      end

      def authentication_failed_message
        t("aikotoba.api.messages.authentication.failed")
      end

      def session_params
        params.require(:account).permit(:email, :password).to_h.symbolize_keys
      end

      # NOTE: Methods to override if you want to do something before sign in.
      def before_sign_in_process
      end

      # NOTE: Methods to override if you want to do something after sign in.
      def after_sign_in_process
      end

      # NOTE: Methods to override if you want to do something failed sign in.
      def failed_sign_in_process
      end
    end
  end
end
