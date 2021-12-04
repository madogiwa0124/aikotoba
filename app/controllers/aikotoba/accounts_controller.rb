# frozen_string_literal: true

module Aikotoba
  class AccountsController < ApplicationController
    def new
    end

    def create
      @account = aikotoba_account_class.build_with_secret(accounts_params)
      if @account.save
        redirect_to after_sign_up_path, flash: {notice: successed_message}
      else
        flash[:alert] = failed_message
        render :new
      end
    end

    private

    def aikotoba_account_class
      Aikotoba.authenticate_class.constantize
    end    

    def after_sign_up_path
      Aikotoba.after_sign_up_path
    end

    def successed_message
      I18n.t(".aikotoba.messages.registration.success", secret: @account.secret)
    end

    def failed_message
      I18n.t(".aikotoba.messages.registration.failed")
    end

    def accounts_params
      {}
    end
  end
end
