# frozen_string_literal: true

module Aikotoba
  class RecoveriesController < ApplicationController
    include Protection::RateLimiting

    def self.recovery_rate_limit_options
      Aikotoba.recovery_rate_limit_options
    end
    private_class_method :recovery_rate_limit_options

    rate_limit(**recovery_rate_limit_options)

    def new
      @account = build_account({email: "", password: ""})
    end

    def create
      account = find_by_send_token_account!(send_recovery_token_params)
      send_recovery_token!(account)
    rescue ActiveRecord::RecordNotFound
      # NOTE: An unknown email gets the same response as a known one, to avoid account
      #       enumeration.
    ensure
      redirect_to success_send_recovery_token_path, flash: {notice: success_send_recovery_token_message}
    end

    def edit
      @account = find_by_has_token_account!(params)
    end

    def update
      @account = find_by_has_token_account!(params)
      recover_account!(@account, recover_accounts_params[:password])
      redirect_to success_recovered_path, flash: {notice: success_recovered_message}
    rescue ActiveRecord::RecordInvalid
      flash[:alert] = failed_message
      render :edit, status: :unprocessable_entity
    end

    private

    def send_recovery_token_params
      params.require(:account).permit(:email)
    end

    def recover_accounts_params
      params.require(:account).permit(:password)
    end

    def build_account(params)
      Account.build_by(attributes: params)
    end

    def find_by_send_token_account!(params)
      Account.for_target_type(aikotoba_authenticate_target).find_by!(email: params[:email])
    end

    def find_by_has_token_account!(params)
      Account::RecoveryToken.active.for_target_type(aikotoba_authenticate_target).find_by!(token: params[:token]).account
    end

    def send_recovery_token!(account)
      Account::Recovery.create_token!(account: account, notify: true)
    end

    def recover_account!(account, new_password)
      Account::Recovery.recover!(account: account, new_password: new_password)
    end

    def success_recovered_path
      aikotoba_scoped_path(:new_session_path)
    end

    def success_send_recovery_token_path
      aikotoba_scoped_path(:new_session_path)
    end

    def failed_message
      I18n.t(".aikotoba.messages.recovery.failed")
    end

    def success_recovered_message
      I18n.t(".aikotoba.messages.recovery.success")
    end

    def success_send_recovery_token_message
      I18n.t(".aikotoba.messages.recovery.sent")
    end
  end
end
