# frozen_string_literal: true

module Aikotoba
  class UnlocksController < ApplicationController
    include Protection::TimingAtack

    before_action :prevent_timing_atack, only: [:update]

    def new
      @account = build_account({email: "", password: ""})
    end

    def create
      account = find_by_send_token_account!(unlock_accounts_params)
      before_send_unlock_token_process
      account.send_unlock_token
      after_send_unlock_token_process
      redirect_to success_send_unlock_token_path, flash: {notice: success_send_unlock_token_message}
    rescue ActiveRecord::RecordNotFound => e
      failed_send_unlock_token_process(e)
      redirect_to failed_send_unlock_token_path, flash: {alert: failed_send_unlock_token_message}
    end

    def update
      account = find_by_has_token_account!(params)
      before_unlock_process
      account.unlock!
      after_unlock_process
      redirect_to after_unlocked_path, flash: {notice: unlocked_message}
    end

    private

    def unlock_accounts_params
      params.require(:account).permit(:email)
    end

    def build_account(params)
      ::Aikotoba::Account.build_account_by(attributes: params)
    end

    def find_by_send_token_account!(params)
      ::Aikotoba::Account.locked.find_by!(email: params[:email])
    end

    def find_by_has_token_account!(params)
      ::Aikotoba::Account.has_unlock_token.find_by!(unlock_token: params[:token])
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

    # NOTE: Methods to override if you want to do something before send unlock token.
    def before_send_unlock_token_process
    end

    # NOTE: Methods to override if you want to do something after send unlock token.
    def after_send_unlock_token_process
    end

    # NOTE: Methods to override if you want to do something failed send unlock token.
    def failed_send_unlock_token_process(e)
    end

    # NOTE: Methods to override if you want to do something before unlock.
    def before_unlock_process
    end

    # NOTE: Methods to override if you want to do something after unlock.
    def after_unlock_process
    end
  end
end
