# frozen_string_literal: true

module Aikotoba
  # NOTE: Where a signed in account sets up TOTP (scans the QR code, confirms with a code) or
  #       turns it off (with a current code), in scopes that list :totp. TOTP's own page, so it
  #       talks to Account::TwoFactor::Totp directly; signing in goes through account.two_factor
  #       like every strategy. An app with its own page calls the same model methods.
  class TotpsController < ApplicationController
    include Authenticatable

    before_action :require_signed_in_account
    before_action :set_totp

    def show
      set_pending_credential
    end

    # NOTE: Already on (the form sent twice, or from another tab) isn't a wrong code: it shows
    #       the page as set up rather than the failure message.
    def create
      if @totp.enable!(params.dig(:totp, :code)) || @totp.usable?
        redirect_to aikotoba_scoped_path(:two_factor_totp_path), notice: enabled_message
      else
        set_pending_credential
        flash.now[:alert] = failed_message
        render :show, status: :unprocessable_entity
      end
    end

    def destroy
      if @totp.disable_with!(params.dig(:totp, :code))
        redirect_to aikotoba_scoped_path(:two_factor_totp_path), notice: disabled_message
      else
        set_pending_credential
        flash.now[:alert] = failed_message
        render :show, status: :unprocessable_entity
      end
    end

    private

    # NOTE: The page sets TOTP up while it isn't (showing the pending secret), and offers to
    #       turn it off once it is (enroll! returns nil, so @credential stays nil).
    #       Showing the page (a GET) may create the pending secret, so it is done in the writing
    #       role, like the token links: an app with automatic role switching sends a GET to the
    #       reading role, where the write would raise ActiveRecord::ReadOnlyError. The check of
    #       whether TOTP is set up happens there too, so a lagging replica can't decide which
    #       page is shown.
    def set_pending_credential
      @credential = ActiveRecord::Base.connected_to(role: :writing) { @totp.enroll! }
    end

    def require_signed_in_account
      aikotoba_request_authentication unless aikotoba_current_account
    end

    def set_totp
      @totp = Account::TwoFactor::Totp.new(account: aikotoba_current_account)
    end

    def enabled_message
      I18n.t(".aikotoba.messages.totp.enabled")
    end

    def disabled_message
      I18n.t(".aikotoba.messages.totp.disabled")
    end

    def failed_message
      I18n.t(".aikotoba.messages.totp.failed")
    end
  end
end
