# frozen_string_literal: true

module Aikotoba
  class ConfirmsController < ApplicationController
    include Confirmable

    def new
      @account = ::Aikotoba::Account.new
    end

    def create
      account = ::Aikotoba::Account.confirmable.find_by!(email: confirm_accounts_params[:email])
      send_confirm_token!(account)
      redirect_to success_send_confirm_token_path, flash: {notice: success_send_confirm_token_message}
    rescue ActiveRecord::RecordNotFound
      redirect_to failed_send_confirm_token_path, flash: {alert: failed_send_confirm_token_message}
    end

    def update
      account = ::Aikotoba::Account.confirmable.find_by!(confirm_token: params[:token])
      account.confirm!
      redirect_to after_confirmed_path, flash: {notice: confirmed_message}
    end

    private

    def confirm_accounts_params
      params.require(:account).permit(:email)
    end

    def enabled_confirmable?
      Aikotoba.enable_confirm
    end

    def after_confirmed_path
      Aikotoba.sign_in_path
    end

    def success_send_confirm_token_path
      Aikotoba.sign_up_path
    end

    def failed_send_confirm_token_path
      Aikotoba.sign_up_path
    end

    def confirmed_message
      I18n.t(".aikotoba.messages.confirmation.success")
    end

    def success_send_confirm_token_message
      I18n.t(".aikotoba.messages.confirmation.sent")
    end

    def failed_send_confirm_token_message
      I18n.t(".aikotoba.messages.confirmation.failed")
    end
  end
end
