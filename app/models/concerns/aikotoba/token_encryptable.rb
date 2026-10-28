# frozen_string_literal: true

module Aikotoba
  module TokenEncryptable
    extend ActiveSupport::Concern

    included do
      encrypts :token, deterministic: true if enabled_aikotoba_enctypted_token?
    end

    module ClassMethods
      def enabled_aikotoba_enctypted_token?
        Aikotoba.encrypted_token
      end
    end
  end
end
