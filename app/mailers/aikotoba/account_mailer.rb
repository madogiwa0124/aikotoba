module Aikotoba
  class AccountMailer < ApplicationMailer
    def confirm
      @account = params[:account]
      @confirm_url = confirmable_confirm_url(token: @account.confirm_token)
      mail(to: @account.email, subject: I18n.t(".aikotoba.mailers.confirm.subject"))
    end

    def unlock
      @account = params[:account]
      @unlock_url = lockable_unlock_url(token: @account.unlock_token)
      mail(to: @account.email, subject: I18n.t(".aikotoba.mailers.unlock.subject"))
    end
  end
end
