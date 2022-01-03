# frozen_string_literal: true

module Aikotoba
  class SessionsController < ApplicationController
    include Authenticatable
    include Authorizable

    before_action :aikotoba_authorize, only: :destroy

    def new
      @account = build_account({email: "", password: ""})
    end

    def create
      @account = authenticate_account(session_params.to_h.symbolize_keys)
      if @account
        before_sign_in_process
        aikotoba_sign_in(@account)
        after_sign_in_process
        redirect_to after_sign_in_path, notice: successed_message
      else
        failed_sign_in_process
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
      ::Aikotoba::Account.build_by(attributes: params)
    end

    def authenticate_account(params)
      ::Aikotoba::Account.authenticate_by(attributes: params)
    end

    def find_account(params)
      ::Aikotoba::Account.find_by(email: params[:email])
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
