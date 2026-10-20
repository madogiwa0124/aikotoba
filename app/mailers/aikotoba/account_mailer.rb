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

      @confirm_url = aikotoba_scoped_url(:confirm_account_url, token: @token.token)
      mail(to: @account.email, subject: I18n.t(".aikotoba.mailers.confirm.subject"))
    end

    def unlock
      @account = params[:account]
      @token = @account.unlock_token
      return unless @token

      @unlock_url = aikotoba_scoped_url(:unlock_account_url, token: @token.token)
      mail(to: @account.email, subject: I18n.t(".aikotoba.mailers.unlock.subject"))
    end

    def recover
      @account = params[:account]
      @token = @account.recovery_token
      return unless @token

      @recover_url = aikotoba_scoped_url(:edit_account_password_url, token: @token.token)
      mail(to: @account.email, subject: I18n.t(".aikotoba.mailers.recover.subject"))
    end

    def magic_link
      @account = params[:account]
      @token = @account.magic_link_token
      return unless @token

      @magic_link_url = aikotoba_scoped_url(:authenticate_via_magic_link_url, token: @token.token)
      mail(to: @account.email, subject: I18n.t(".aikotoba.mailers.magic_link.subject"))
    end

    private

    def aikotoba_scoped_url(route, **params)
      scope = Aikotoba.scope_name_for(@account.authenticate_target_type)
      name = (scope == "default") ? route : :"#{scope}_#{route}"
      # NOTE: The name is built from config, never from request input, but only ever
      #       public_send an engine route helper, not other public methods on the proxy.
      raise ArgumentError, "not an Aikotoba route helper: #{name}" unless Aikotoba::Engine.routes.named_routes.route_defined?(name)

      aikotoba.public_send(name, **params)
    end
  end
end
