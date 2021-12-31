# frozen_string_literal: true

module Aikotoba
  class RecoveriesController < ApplicationController
    include Recoverable

    def new
      @account = ::Aikotoba::Account.new
    end

    def create
      account = ::Aikotoba::Account.find_by!(email: send_recover_token_params[:email])
      send_recover_token!(account)
      redirect_to success_send_recover_token_path, flash: {notice: success_send_recover_token_message}
    rescue ActiveRecord::RecordNotFound
      redirect_to failed_send_recover_token_path, flash: {alert: failed_send_recover_token_message}
    end

    def edit
      @account = ::Aikotoba::Account.find_by!(recover_token: params[:token])
    end

    def update
      @account = ::Aikotoba::Account.find_by!(recover_token: params[:token])
      @account.recover!(password: recover_accounts_params[:password])
      redirect_to success_recovered_path, flash: {notice: success_recovered_message}
    rescue ActiveRecord::RecordInvalid
      @account.recover_token = params[:token]
      flash[:alert] = failed_message
      render :edit
    end

    private

    def send_recover_token_params
      params.require(:account).permit(:email)
    end

    def recover_accounts_params
      params.require(:account).permit(:password)
    end

    def success_recovered_path
      Aikotoba.sign_in_path
    end

    def success_send_recover_token_path
      Aikotoba.sign_in_path
    end

    def failed_send_recover_token_path
      Aikotoba.sign_in_path
    end

    def failed_message
      I18n.t(".aikotoba.messages.recovery.failed")
    end

    def success_recovered_message
      I18n.t(".aikotoba.messages.recovery.success")
    end

    def success_send_recover_token_message
      I18n.t(".aikotoba.messages.recovery.sent")
    end

    def failed_send_recover_token_message
      I18n.t(".aikotoba.messages.recovery.sent_failed")
    end
  end
end
