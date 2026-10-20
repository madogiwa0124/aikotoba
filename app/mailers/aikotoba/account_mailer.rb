module Aikotoba
  # NOTE: These run from deliver_later, so the token is read when the job runs, not when
  #       it was enqueued. Reading the account's current token is deliberate: issuing a new
  #       token destroys the previous one, so the latest is the only link that still works.
  #       It can also be gone by then (used, or cleared by unlock!), in which case nothing is
  #       sent -- returning without calling `mail` makes the delivery a no-op.
  class AccountMailer < ApplicationMailer
    def confirm
      @account = params[:account]
      @token = @account.confirmation_token
      return unless @token

      @confirm_url = aikotoba.confirm_account_url(token: @token.token)
      mail(to: @account.email, subject: I18n.t(".aikotoba.mailers.confirm.subject"))
    end

    def unlock
      @account = params[:account]
      @token = @account.unlock_token
      return unless @token

      @unlock_url = aikotoba.unlock_account_url(token: @token.token)
      mail(to: @account.email, subject: I18n.t(".aikotoba.mailers.unlock.subject"))
    end

    def recover
      @account = params[:account]
      @token = @account.recovery_token
      return unless @token

      @recover_url = aikotoba.edit_account_password_url(token: @token.token)
      mail(to: @account.email, subject: I18n.t(".aikotoba.mailers.recover.subject"))
    end

    def magic_link
      @account = params[:account]
      @token = @account.magic_link_token
      return unless @token

      @magic_link_url = aikotoba.authenticate_via_magic_link_url(token: @token.token)
      mail(to: @account.email, subject: I18n.t(".aikotoba.mailers.magic_link.subject"))
    end
  end
end
