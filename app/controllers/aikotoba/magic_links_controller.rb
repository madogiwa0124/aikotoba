# frozen_string_literal: true

module Aikotoba
  class MagicLinksController < ApplicationController
    include Authenticatable
    include Protection::RateLimiting

    def self.magic_link_rate_limit_options
      Aikotoba.magic_link_rate_limit_options
    end
    private_class_method :magic_link_rate_limit_options

    rate_limit(**magic_link_rate_limit_options)

    def new
      @account = build_account({email: ""})
    end

    def create
      # NOTE: An unknown email gets the same response as a known one, to avoid account
      #       enumeration.
      account = find_by_send_token_account(magic_link_accounts_params)
      send_magic_link_token!(account) if account
      redirect_to success_send_magic_link_token_path, flash: {notice: success_send_magic_link_token_message}
    end

    def update
      # NOTE: Sign-in is done using a URL token (a GET request), so both consuming the
      #       token and establishing the session are done in the writing role -- unlike
      #       Confirm/Unlock, which only flip a boolean flag, this also creates an
      #       Account::Session record via aikotoba_sign_in.
      ActiveRecord::Base.connected_to(role: :writing) do
        account = authenticate_account!(params[:token])
        aikotoba_sign_in(account)
      end
      redirect_to after_sign_in_path, flash: {notice: successed_message}
    end

    private

    def magic_link_accounts_params
      params.require(:account).permit(:email)
    end

    def build_account(params)
      Account.new(params)
    end

    def find_by_send_token_account(params)
      Account.for_target_type(aikotoba_authenticate_target).find_by(email: params[:email])
    end

    def send_magic_link_token!(account)
      Account::MagicLink.create_token!(account: account, notify: true)
    end

    def authenticate_account!(token)
      Account::MagicLink.authenticate_by(token: token, target_type_name: aikotoba_authenticate_target) || raise(ActiveRecord::RecordNotFound)
    end

    def after_sign_in_path
      aikotoba_after_authentication_path
    end

    def success_send_magic_link_token_path
      aikotoba_scoped_path(:new_session_path)
    end

    def successed_message
      I18n.t(".aikotoba.messages.authentication.success")
    end

    def success_send_magic_link_token_message
      I18n.t(".aikotoba.messages.magic_link.sent")
    end
  end
end
