# frozen_string_literal: true

module Aikotoba
  module Confirmable
    extend ActiveSupport::Concern

    def send_confirm_token!(account)
      account.update_confirm_token!
      account.send_confirm_token
    end
  end
end
