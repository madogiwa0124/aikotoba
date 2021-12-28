# frozen_string_literal: true

module Aikotoba
  module Confirmable
    extend ActiveSupport::Concern

    def send_confirm_token_if_confirmable!(account)
      return unless ::Aikotoba::Account.enable_confirm?
      account.update_confirm_token!
      account.send_confirm_token
    end
  end
end
