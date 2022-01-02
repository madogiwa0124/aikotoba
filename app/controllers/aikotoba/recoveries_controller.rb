# frozen_string_literal: true

module Aikotoba
  class RecoveriesController < ApplicationController
    include Recoverable
    include Protection::TimingAtack

    before_action :prevent_timing_atack, only: [:edit, :update]

    def new
      @account = build_account({email: "", password: ""})
    end

    def create
      account = find_by_send_token_account!(send_recover_token_params)
      before_send_recover_token_process
      send_recover_token!(account)
      after_send_recover_token_process
      redirect_to success_send_recover_token_path, flash: {notice: success_send_recover_token_message}
    rescue ActiveRecord::RecordNotFound => e
      failed_send_recover_token_process(e)
      redirect_to failed_send_recover_token_path, flash: {alert: failed_send_recover_token_message}
    end

    def edit
      @account = find_by_has_token_account!(params)
    end

    def update
      @account = find_by_has_token_account!(params)
      before_recover_process
      @account.recover!(password: recover_accounts_params[:password])
      after_recover_process
      redirect_to success_recovered_path, flash: {notice: success_recovered_message}
    rescue ActiveRecord::RecordInvalid => e
      failed_recover_process(e)
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

    def build_account(params)
      ::Aikotoba::Account.build_by(attributes: params)
    end

    def find_by_send_token_account!(params)
      ::Aikotoba::Account.find_by!(email: params[:email])
    end

    def find_by_has_token_account!(params)
      ::Aikotoba::Account.has_recover_token.find_by!(recover_token: params[:token])
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

    # NOTE: Methods to override if you want to do something before send recover token.
    def before_send_recover_token_process
    end

    # NOTE: Methods to override if you want to do something after send recover token.
    def after_send_recover_token_process
    end

    # NOTE: Methods to override if you want to do something failed send recover token.
    def failed_send_recover_token_process(e)
    end

    # NOTE: Methods to override if you want to do something before recover.
    def before_recover_process
    end

    # NOTE: Methods to override if you want to do something after recover.
    def after_recover_process
    end

    # NOTE: Methods to override if you want to do something failed recover.
    def failed_recover_process(e)
    end
  end
end
