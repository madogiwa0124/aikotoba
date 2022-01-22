module Aikotoba
  class AccountMailer < ApplicationMailer
    def confirm
      @account = params[:account]
      @confirm_url = aikotoba.confirm_account_url(token: @account.confirmation_token.token)
      mail(to: @account.email, subject: I18n.t(".aikotoba.mailers.confirm.subject"))
    end

    def unlock
      @account = params[:account]
      @unlock_url = aikotoba.unlock_account_url(token: @account.unlock_token.token)
      mail(to: @account.email, subject: I18n.t(".aikotoba.mailers.unlock.subject"))
    end

    def recover
      @account = params[:account]
      @recover_url = aikotoba.edit_account_password_url(token: @account.recovery_token.token)
      mail(to: @account.email, subject: I18n.t(".aikotoba.mailers.recover.subject"))
    end
  end
end
