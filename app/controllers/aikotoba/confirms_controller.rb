# frozen_string_literal: true

module Aikotoba
  class ConfirmsController < ApplicationController
    include Protection::RateLimiting

    def self.confirmation_rate_limit_options
      Aikotoba.confirmation_rate_limit_options
    end
    private_class_method :confirmation_rate_limit_options

    rate_limit(**confirmation_rate_limit_options)

    def new
      @account = build_account({email: "", password: ""})
    end

    def create
      # NOTE: An unknown email gets the same response as a known one, to avoid account
      #       enumeration.
      account = find_by_send_token_account(confirm_accounts_params)
      send_token_account!(account) if account
      redirect_to success_send_confirmation_token_path, flash: {notice: success_send_confirmation_token_message}
    end

    def update
      account = find_by_has_token_account!(params)
      confirm_account!(account)
      redirect_to after_confirmed_path, flash: {notice: confirmed_message}
    end

    private

    def confirm_accounts_params
      params.require(:account).permit(:email)
    end

    def build_account(params)
      Account.build_by(attributes: params)
    end

    def find_by_send_token_account(params)
      Account.for_target_type(aikotoba_authenticate_target).unconfirmed.find_by(email: params[:email])
    end

    def send_token_account!(account)
      Account::Confirmation.create_token!(account: account, notify: true)
    end

    def find_by_has_token_account!(params)
      Account::ConfirmationToken.active.for_target_type(aikotoba_authenticate_target).find_by!(token: params[:token]).account
    end

    def confirm_account!(account)
      # NOTE: Confirmation is done using URL tokens, so it is done in the writing role.
      ActiveRecord::Base.connected_to(role: :writing) do
        Account::Confirmation.confirm!(account: account)
      end
    end

    def after_confirmed_path
      aikotoba_scoped_path(:new_session_path)
    end

    def success_send_confirmation_token_path
      aikotoba_scoped_path(:new_session_path)
    end

    def confirmed_message
      I18n.t(".aikotoba.messages.confirmation.success")
    end

    def success_send_confirmation_token_message
      I18n.t(".aikotoba.messages.confirmation.sent")
    end
  end
end
