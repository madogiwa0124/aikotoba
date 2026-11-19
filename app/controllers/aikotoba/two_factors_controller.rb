# frozen_string_literal: true

module Aikotoba
  # NOTE: The second step of a password sign in to a scope with two_factor_strategies:
  #       the challenge started by SessionsController#create (via aikotoba_begin_sign_in) is
  #       answered here, and the session starts only once it succeeds. Knows nothing about the
  #       strategy beyond its key: account.two_factor checks the answer, and the page renders
  #       the strategy's own partial. Reached without a sign in in progress, it sends the user
  #       back to the sign in page.
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

    # NOTE: Three outcomes, all for the account that passed the password: the code matched
    #       (sign in); it didn't, but the challenge can still be answered, so the same code
    #       may be tried again; or it can't be any more (the code expired or used up its
    #       attempts, or the account was locked), so the sign in starts over from the password.
    def create
      two_factor = @two_factor_account.two_factor
      options = {strategy: @two_factor_strategy, target_type_name: aikotoba_authenticate_target}
      if two_factor.authenticate(params.dig(:two_factor, :code), **options)
        aikotoba_two_factor_challenge_store.clear
        aikotoba_sign_in(@two_factor_account, two_factor: :verified)
        redirect_to after_sign_in_path, notice: successed_message
      elsif two_factor.challenge_active?(**options)
        flash.now[:alert] = failed_message
        render :new, status: :unprocessable_entity
      else
        aikotoba_two_factor_challenge_store.clear
        redirect_to aikotoba_scoped_path(:new_session_path), alert: expired_message
      end
    end

    private

    def redirect_signed_in_account
      redirect_to after_sign_in_path if aikotoba_current_account
    end

    # NOTE: The account is looked up once here; whether it may still sign in to the scope is
    #       account.two_factor's check. One deleted since the password step starts over.
    #       Without a sign in in progress the user goes back to sign in, with the "expired"
    #       message only when one had started (it expired, or its account or strategy is gone):
    #       someone who opened the page directly has nothing that expired.
    def require_two_factor_in_progress
      store = aikotoba_two_factor_challenge_store
      challenge = store.current
      @two_factor_account = Account.find_by(id: challenge["account_id"]) if challenge
      if @two_factor_account
        @two_factor_strategy = challenge["strategy"]
        return
      end

      flash[:alert] = expired_message if store.started?
      store.clear
      redirect_to aikotoba_scoped_path(:new_session_path)
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
