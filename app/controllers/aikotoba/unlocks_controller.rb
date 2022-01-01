# frozen_string_literal: true

module Aikotoba
  class UnlocksController < ApplicationController
    def new
      @account = ::Aikotoba::Account.new
    end

    def create
      account = ::Aikotoba::Account.locked.find_by!(email: unlock_accounts_params[:email])
      account.send_unlock_token
      redirect_to success_send_unlock_token_path, flash: {notice: success_send_unlock_token_message}
    rescue ActiveRecord::RecordNotFound
      redirect_to failed_send_unlock_token_path, flash: {alert: failed_send_unlock_token_message}
    end

    def update
      account = ::Aikotoba::Account.has_unlock_token.find_by!(unlock_token: params[:token])
      account.unlock!
      redirect_to after_unlocked_path, flash: {notice: unlocked_message}
    end

    private

    def unlock_accounts_params
      params.require(:account).permit(:email)
    end

    def after_unlocked_path
      Aikotoba.sign_in_path
    end

    def success_send_unlock_token_path
      Aikotoba.sign_in_path
    end

    def failed_send_unlock_token_path
      Aikotoba.unlock_path
    end

    def unlocked_message
      I18n.t(".aikotoba.messages.unlocking.success")
    end

    def success_send_unlock_token_message
      I18n.t(".aikotoba.messages.unlocking.sent")
    end

    def failed_send_unlock_token_message
      I18n.t(".aikotoba.messages.unlocking.failed")
    end
  end
end
