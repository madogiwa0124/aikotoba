# frozen_string_literal: true

module Aikotoba
  class UnlocksController < ApplicationController
    include Protection::RateLimiting

    def self.unlock_rate_limit_options
      Aikotoba.unlock_rate_limit_options
    end
    private_class_method :unlock_rate_limit_options

    rate_limit(**unlock_rate_limit_options)

    def new
      @account = build_account({email: "", password: ""})
    end

    def create
      account = begin
        find_by_send_token_account!(unlock_accounts_params)
      rescue ActiveRecord::RecordNotFound
        # NOTE: An unknown email gets the same response as a known one, to avoid account
        #       enumeration. Only the lookup is rescued, so an error from issuing the token
        #       is raised rather than answered with the success message.
        nil
      end
      send_token_account!(account) if account
      redirect_to success_send_unlock_token_path, flash: {notice: success_send_unlock_token_message}
    end

    def update
      account = find_by_has_token_account!(params)
      unlock_account!(account)
      redirect_to after_unlocked_path, flash: {notice: unlocked_message}
    end

    private

    def unlock_accounts_params
      params.require(:account).permit(:email)
    end

    def build_account(params)
      Account.build_by(attributes: params)
    end

    def find_by_send_token_account!(params)
      Account.for_target_type(aikotoba_authenticate_target).locked.find_by!(email: params[:email])
    end

    def send_token_account!(account)
      Account::Lock.create_token!(account: account, notify: true)
    end

    def find_by_has_token_account!(params)
      Account::UnlockToken.active.for_target_type(aikotoba_authenticate_target).find_by!(token: params[:token]).account
    end

    def unlock_account!(account)
      # NOTE: Unlocking is done using URL tokens, so it is done in the writing role.
      ActiveRecord::Base.connected_to(role: :writing) do
        Account::Lock.unlock!(account: account)
      end
    end

    def after_unlocked_path
      aikotoba_scoped_path(:new_session_path)
    end

    def success_send_unlock_token_path
      aikotoba_scoped_path(:new_session_path)
    end

    def unlocked_message
      I18n.t(".aikotoba.messages.unlocking.success")
    end

    def success_send_unlock_token_message
      I18n.t(".aikotoba.messages.unlocking.sent")
    end
  end
end
