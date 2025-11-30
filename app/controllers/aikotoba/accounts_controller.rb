# frozen_string_literal: true

module Aikotoba
  class AccountsController < ApplicationController
    def new
      @account = build_account({email: "", password: ""})
    end

    def create
      @account = build_account(accounts_params.to_h.symbolize_keys)
      ActiveRecord::Base.transaction do
        before_create_account_process
        save_with_callbacks!(@account)
        after_create_account_process
      end
      redirect_to after_sign_up_path, flash: {notice: successed_message}
    rescue ActiveRecord::RecordInvalid => e
      failed_create_account_process(e)
      flash[:alert] = failed_message
      render :new, status: :unprocessable_entity
    end

    private

    def accounts_params
      params.require(:account).permit(:email, :password)
    end

    def build_account(params)
      Account.build_by(attributes: params)
    end

    def save_with_callbacks!(account)
      Account::Registration.call!(account: account)
    end

    def after_sign_up_path
      aikotoba.new_session_path
    end

    def successed_message
      I18n.t(".aikotoba.messages.registration.success")
    end

    def failed_message
      I18n.t(".aikotoba.messages.registration.failed")
    end

    # NOTE: Methods to override if you want to do something before account creation.
    def before_create_account_process
    end

    # NOTE: Methods to override if you want to do something after account creation.
    def after_create_account_process
    end

    # NOTE: Methods to override if you want to do something failed account creation.
    def failed_create_account_process(e)
    end
  end
end
