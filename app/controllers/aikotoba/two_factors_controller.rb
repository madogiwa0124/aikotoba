# frozen_string_literal: true

module Aikotoba
  # NOTE: The second step of a password sign in to a scope with two_factor_authenticatable:
  #       the code sent by SessionsController#create (via aikotoba_begin_sign_in) is entered
  #       here, and the session starts only once it matches. Reached without a sign in in
  #       progress, it sends the user back to the sign in page.
  class TwoFactorsController < ApplicationController
    include Authenticatable
    include Protection::RateLimiting

    def self.two_factor_rate_limit_options
      Aikotoba.two_factor_rate_limit_options
    end
    private_class_method :two_factor_rate_limit_options

    aikotoba_rate_limit(two_factor_rate_limit_options)

    before_action :redirect_signed_in_account
    before_action :require_two_factor_in_progress

    def new
    end

    def create
      account = authenticate_account(params.dig(:two_factor, :code))
      if account
        clear_aikotoba_two_factor
        aikotoba_sign_in(account)
        redirect_to after_sign_in_path, notice: successed_message
      elsif code_active?
        flash.now[:alert] = failed_message
        render :new, status: :unprocessable_entity
      else
        clear_aikotoba_two_factor
        redirect_to aikotoba_scoped_path(:new_session_path), alert: expired_message
      end
    end

    private

    def redirect_signed_in_account
      redirect_to after_sign_in_path if aikotoba_current_account
    end

    def require_two_factor_in_progress
      return if aikotoba_two_factor_account_id

      redirect_to aikotoba_scoped_path(:new_session_path), alert: expired_message
    end

    def authenticate_account(code)
      Account::EmailOtp.authenticate_by(
        account_id: aikotoba_two_factor_account_id,
        code: code,
        target_type_name: aikotoba_authenticate_target
      )
    end

    def code_active?
      Account::EmailOtp.code_active?(account_id: aikotoba_two_factor_account_id, target_type_name: aikotoba_authenticate_target)
    end

    def after_sign_in_path
      aikotoba_after_authentication_path
    end

    def successed_message
      I18n.t(".aikotoba.messages.authentication.success")
    end

    def failed_message
      I18n.t(".aikotoba.messages.two_factor.failed")
    end

    def expired_message
      I18n.t(".aikotoba.messages.two_factor.expired")
    end
  end
end
