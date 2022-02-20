# frozen_string_literal: true

module Aikotoba
  module TokenEncryptable
    extend ActiveSupport::Concern

    included do
      if enabled_aikotoba_enctypted_token?
        if available_active_record_encryption?
          encrypts :token, deterministic: true
        else
          raise Errors::NotAvailableException, "You need to be able to encrypt the token using Active Record Encryption."
        end
      end
    end

    module ClassMethods
      def enabled_aikotoba_enctypted_token?
        Aikotoba.encypted_token
      end

      def available_active_record_encryption?
        ActiveRecord::VERSION::MAJOR >= 7
      end
    end
  end
end
