# frozen_string_literal: true

module Aikotoba
  class UnlocksController < ApplicationController
    def new
      @account = build_account({email: "", password: ""})
    end

    def create
      account = find_by_send_token_account!(unlock_accounts_params)
      before_send_unlock_token_process
      send_token_account!(account)
      after_send_unlock_token_process
      redirect_to success_send_unlock_token_path, flash: {notice: success_send_unlock_token_message}
    rescue ActiveRecord::RecordNotFound => e
      failed_send_unlock_token_process(e)
      @account = build_account({email: "", password: ""})
      flash[:alert] = failed_send_unlock_token_message
      render :new, status: :unprocessable_entity
    end

    def update
      account = find_by_has_token_account!(params)
      before_unlock_process
      unlock_account!(account)
      after_unlock_process
      redirect_to after_unlocked_path, flash: {notice: unlocked_message}
    end

    private

    def unlock_accounts_params
      params.require(:account).permit(:email)
    end

    def build_account(params)
      Account.build_by(attributes: params)
    end

    def find_by_send_token_account!(params)
      Account.locked.find_by!(email: params[:email])
    end

    def send_token_account!(account)
      Account::Service::Lock.create_unlock_token!(account: account, notify: true)
    end

    def find_by_has_token_account!(params)
      Account::UnlockToken.active.find_by!(token: params[:token]).account
    end

    def unlock_account!(account)
      # NOTE: Unlocking is done using URL tokens, so it is done in the writing role.
      ActiveRecord::Base.connected_to(role: :writing) do
        Account::Service::Lock.unlock!(account: account)
      end
    end

    def after_unlocked_path
      aikotoba.new_session_path
    end

    def success_send_unlock_token_path
      aikotoba.new_session_path
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
