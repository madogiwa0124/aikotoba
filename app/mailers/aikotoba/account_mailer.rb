module Aikotoba
  class AccountMailer < ApplicationMailer
    def confirm
      @account = params[:account]
      @token = @account.confirmation_token
      @confirm_url = aikotoba.confirm_account_url(token: @token.token)
      mail(to: @account.email, subject: I18n.t(".aikotoba.mailers.confirm.subject"))
    end

    def unlock
      @account = params[:account]
      @token = @account.unlock_token
      @unlock_url = aikotoba.unlock_account_url(token: @token.token)
      mail(to: @account.email, subject: I18n.t(".aikotoba.mailers.unlock.subject"))
    end

    def recover
      @account = params[:account]
      @token = @account.recovery_token
      @recover_url = aikotoba.edit_account_password_url(token: @token.token)
      mail(to: @account.email, subject: I18n.t(".aikotoba.mailers.recover.subject"))
    end

    def magic_link
      @account = params[:account]
      @token = @account.magic_link_token
      @magic_link_url = aikotoba.authenticate_via_magic_link_url(token: @token.token)
      mail(to: @account.email, subject: I18n.t(".aikotoba.mailers.magic_link.subject"))
    end
  end
end
