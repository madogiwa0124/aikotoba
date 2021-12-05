# frozen_string_literal: true

module Aikotoba
  class AccountsController < ApplicationController
    def new
      @account = ::Aikotoba::Account.new(strategy: Aikotoba.authentication_strategy)
    end

    def create
      @account = ::Aikotoba::Account.build_account_by(accounts_params.to_h)
      ActiveRecord::Base.transaction do
        @account.save!
        after_create_account_process
      end
      redirect_to after_sign_up_path, flash: {notice: successed_message}
    rescue ActiveRecord::RecordInvalid
      flash[:alert] = failed_message
      render :new
    end

    private

    # NOTE: Methods to override if you want to do something after account creation.
    def after_create_account_process
    end

    def after_sign_up_path
      Aikotoba.after_sign_up_path
    end

    # FIXME: I want to be able to handle strategies in the same way.
    def successed_message
      message = I18n.t(".aikotoba.messages.registration.success")
      if @account.password_only?
        message + I18n.t(".aikotoba.messages.registration.show_password", password: @account.password)
      else
        message
      end
    end

    def failed_message
      I18n.t(".aikotoba.messages.registration.failed")
    end

    def accounts_params
      params.require(:account).permit(:email, :password, :strategy)
    end
  end
end
