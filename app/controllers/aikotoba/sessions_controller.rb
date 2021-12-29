# frozen_string_literal: true

module Aikotoba
  class SessionsController < ApplicationController
    include Authenticatable
    include Authorizable
    include Lockable

    before_action :aikotoba_authorize, only: :destroy

    def new
      @account = ::Aikotoba::Account.new(strategy: Aikotoba.authentication_strategy)
    end

    def create
      @account = ::Aikotoba::Account.find_account_by(strategy: session_params[:strategy], attributes: session_params.to_h.symbolize_keys)
      if @account
        aikotoba_sign_in(@account)
        reset_lock_status_if_lockable!(@account)
        redirect_to after_sign_in_path, notice: successed_message
      else
        lock_if_lockable_and_exceed_max_failed_attempts!(session_params[:strategy], session_params[:email])
        redirect_to failed_sign_in_path, alert: failed_message
      end
    end

    def destroy
      aikotoba_sign_out
      redirect_to after_sign_out_path, notice: signed_out_message
    end

    private

    def session_params
      params.require(:account).permit(:email, :password, :strategy)
    end

    def after_sign_in_path
      Aikotoba.after_sign_in_path
    end

    def failed_sign_in_path
      Aikotoba.failed_sign_in_path
    end

    def after_sign_out_path
      Aikotoba.after_sign_out_path
    end

    def successed_message
      I18n.t(".aikotoba.messages.authentication.success")
    end

    def failed_message
      I18n.t(".aikotoba.messages.authentication.failed")
    end

    def signed_out_message
      I18n.t(".aikotoba.messages.authentication.sign_out")
    end
  end
end
