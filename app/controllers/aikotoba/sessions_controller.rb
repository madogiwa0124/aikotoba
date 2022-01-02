# frozen_string_literal: true

module Aikotoba
  class SessionsController < ApplicationController
    include Authenticatable
    include Authorizable
    include Lockable

    before_action :aikotoba_authorize, only: :destroy

    def new
      @account = build_account({email: "", password: ""})
    end

    def create
      @account = find_account(session_params.to_h.symbolize_keys)
      if @account
        before_sign_in_process
        aikotoba_sign_in(@account)
        after_sign_in_process
        reset_lock_status!(@account) if enable_lock?
        redirect_to after_sign_in_path, notice: successed_message
      else
        failed_sign_in_process
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

    def build_account(params)
      ::Aikotoba::Account.build_account_by(attributes: params)
    end

    def find_account(params)
      ::Aikotoba::Account.find_account_by(attributes: params)
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

    # NOTE: Methods to override if you want to do something before sign in.
    def before_sign_in_process
    end

    # NOTE: Methods to override if you want to do something after sign in.
    def after_sign_in_process
    end

    # NOTE: Methods to override if you want to do something failed sign in.
    def failed_sign_in_process(e = nil)
    end
  end
end
