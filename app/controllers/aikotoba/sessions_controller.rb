# frozen_string_literal: true

module Aikotoba
  class SessionsController < ApplicationController
    include Authenticatable
    include Protection::RateLimiting

    def self.sign_in_rate_limit_options
      Aikotoba.sign_in_rate_limit_options
    end
    private_class_method :sign_in_rate_limit_options

    aikotoba_rate_limit(sign_in_rate_limit_options)

    def new
      return redirect_to after_sign_in_path if aikotoba_current_account
      @account = build_account({email: "", password: ""})
    end

    def create
      @account = authenticate_account(session_params.to_h.symbolize_keys)
      if @account
        aikotoba_sign_in(@account)
        redirect_to after_sign_in_path, notice: successed_message
      else
        @account = build_account({email: "", password: ""})
        flash[:alert] = failed_message
        render :new, status: :unprocessable_entity
      end
    end

    def destroy
      aikotoba_sign_out if aikotoba_current_account
      redirect_to after_sign_out_path, notice: signed_out_message
    end

    private

    def session_params
      params.require(:account).permit(:email, :password)
    end

    def build_account(params)
      Account.build_by(attributes: params)
    end

    def authenticate_account(params)
      Account::PasswordHash.authenticate_by(attributes: params, target_type_name: aikotoba_authenticate_target)
    end

    def after_sign_in_path
      aikotoba_after_authentication_path
    end

    def after_sign_out_path
      aikotoba_scope_config[:after_sign_out_path]
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
