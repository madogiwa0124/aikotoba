# frozen_string_literal: true

module Aikotoba
  class SessionsController < ApplicationController
    include ControllerHelper

    def new
    end

    def create
      @account = account_class.find_by_secret(session_params[:secret])
      if @account
        sign_in(@account)
        redirect_to after_sign_in_path, notice: successed_message
      else
        redirect_to failed_sign_in_path, alert: failed_message
      end
    end

    def destory
      sign_out
      redirect_to after_sign_out_path
    end

    private

    def session_params
      params.require(:account).permit(:secret)
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
  end
end
