# frozen_string_literal: true

module Aikotoba
  class Account::Strategy::Base
    class << self
      def build_account_by(attributes)
        raise NotImplementedError
      end

      def find_account_by(credentials)
        raise NotImplementedError
      end

      def confirmable?
        raise NotImplementedError
      end

      def lockable?
        raise NotImplementedError
      end

      private

      def warning_not_supported
        if Aikotoba::Account.enable_confirm? && !confirmable?
          Rails.logger.warn("#{name} is not supported confirmable. Please set Aikotoba.enable_confirm to false or use a different strategy.")
        end
        if Aikotoba::Account.enable_lock? && !lockable?
          Rails.logger.warn("#{name} is not supported lockable. Please set Aikotoba.enable_lock to false or use a different strategy.")
        end
      end
    end
  end
end
