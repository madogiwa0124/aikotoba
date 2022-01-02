# frozen_string_literal: true

module Aikotoba
  module Confirmable
    extend ActiveSupport::Concern

    def send_confirmation_token!(account)
      account.update_confirmation_token!
      account.send_confirmation_token
    end
  end
end
