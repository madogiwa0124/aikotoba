# frozen_string_literal: true

module Aikotoba
  class SessionsController < ApplicationController
    include Authenticatable
    include Authorizable

    before_action :aikotoba_authorize, only: :destroy

    def new
    end

    def create
      @account = ::Aikotoba::Account.find_account_by(session_params.to_h)
      if @account
        aikotoba_sign_in(@account)
        redirect_to after_sign_in_path, notice: successed_message
      else
        redirect_to failed_sign_in_path, alert: failed_message
      end
    end

    def destroy
      aikotoba_sign_out
      redirect_to after_sign_out_path, notice: signed_out_message
    end

    private

    def session_params
      params.require(:account).permit(:password)
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
