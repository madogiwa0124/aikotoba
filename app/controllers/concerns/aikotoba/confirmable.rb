# frozen_string_literal: true

module Aikotoba
  module Confirmable
    extend ActiveSupport::Concern

    def send_confirmation_token!(account)
      account.build_confirmation_token.save!
      account.confirmation_token.notify
    end
  end
end
