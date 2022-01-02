# frozen_string_literal: true

module Aikotoba
  module Recoverable
    extend ActiveSupport::Concern

    def send_recovery_token!(account)
      account.update_recovery_token!
      account.send_recovery_token
    end
  end
end
