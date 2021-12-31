# frozen_string_literal: true

module Aikotoba
  module Recoverable
    extend ActiveSupport::Concern

    def send_recover_token!(account)
      account.update_recover_token!
      account.send_recover_token
    end
  end
end
