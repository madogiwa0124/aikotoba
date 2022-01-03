# frozen_string_literal: true

module Aikotoba
  class ConfirmsController < ApplicationController
    include Protection::TimingAtack

    before_action :prevent_timing_atack, only: [:update]

    def new
      @account = build_account({email: "", password: ""})
    end

    def create
      account = find_by_send_token_account!(confirm_accounts_params)
      before_send_confirmation_token_process
      account.send_confirmation_token!
      after_send_confirmation_token_process
      redirect_to success_send_confirmation_token_path, flash: {notice: success_send_confirmation_token_message}
    rescue ActiveRecord::RecordNotFound => e
      failed_send_confirmation_token_process(e)
      redirect_to failed_send_confirmation_token_path, flash: {alert: failed_send_confirmation_token_message}
    end

    def update
      account = find_by_has_token_account!(params)
      before_confirm_process
      account.confirm!
      after_confirm_process
      redirect_to after_confirmed_path, flash: {notice: confirmed_message}
    end

    private

    def confirm_accounts_params
      params.require(:account).permit(:email)
    end

    def build_account(params)
      ::Aikotoba::Account.build_by(attributes: params)
    end

    def find_by_send_token_account!(params)
      ::Aikotoba::Account.unconfirmed.find_by!(email: params[:email])
    end

    def find_by_has_token_account!(params)
      ::Aikotoba::Account::ConfirmationToken.find_by!(token: params[:token]).account
    end

    def enabled_confirmable?
      Aikotoba.enable_confirm
    end

    def after_confirmed_path
      Aikotoba.sign_in_path
    end

    def success_send_confirmation_token_path
      Aikotoba.sign_up_path
    end

    def failed_send_confirmation_token_path
      Aikotoba.sign_up_path
    end

    def confirmed_message
      I18n.t(".aikotoba.messages.confirmation.success")
    end

    def success_send_confirmation_token_message
      I18n.t(".aikotoba.messages.confirmation.sent")
    end

    def failed_send_confirmation_token_message
      I18n.t(".aikotoba.messages.confirmation.failed")
    end

    # NOTE: Methods to override if you want to do something before send confirm token.
    def before_send_confirmation_token_process
    end

    # NOTE: Methods to override if you want to do something after send confirm token.
    def after_send_confirmation_token_process
    end

    # NOTE: Methods to override if you want to do something failed send confirm token.
    def failed_send_confirmation_token_process(e)
    end

    # NOTE: Methods to override if you want to do something before confirm.
    def before_confirm_process
    end

    # NOTE: Methods to override if you want to do something after confirm.
    def after_confirm_process
    end
  end
end
