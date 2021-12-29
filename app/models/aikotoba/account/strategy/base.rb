# frozen_string_literal: true

module Aikotoba
  module Account::Strategy
    class InvalidAttributeError < StandardError; end

    class Base
      class << self
        def build_account_by(attributes)
          raise NotImplementedError
        end

        def find_account_by(credentials)
          raise NotImplementedError
        end
      end
    end
  end
end
