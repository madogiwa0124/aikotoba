# frozen_string_literal: true

module Aikotoba
  module Recoverable
    extend ActiveSupport::Concern

    def send_recovery_token!(account)
      account.build_recovery_token.save!
      account.recovery_token.notify
    end
  end
end
