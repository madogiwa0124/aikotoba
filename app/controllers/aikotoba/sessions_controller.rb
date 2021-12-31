# frozen_string_literal: true

module Aikotoba
  class SessionsController < ApplicationController
    include Authenticatable
    include Authorizable
    include Lockable

    before_action :aikotoba_authorize, only: :destroy

    def new
      @account = ::Aikotoba::Account.new
    end

    def create
      @account = ::Aikotoba::Account.find_account_by(attributes: session_params.to_h.symbolize_keys)
      if @account
        aikotoba_sign_in(@account)
        reset_lock_status!(@account) if enable_lock?
        redirect_to after_sign_in_path, notice: successed_message
      else
        lock_if_exceed_max_failed_attempts!(email: session_params[:email]) if enable_lock?
        redirect_to failed_sign_in_path, alert: failed_message
      end
    end

    def destroy
      aikotoba_sign_out
      redirect_to after_sign_out_path, notice: signed_out_message
    end

    private

    def session_params
      params.require(:account).permit(:email, :password)
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
