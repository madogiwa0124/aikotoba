# frozen_string_literal: true

module Aikotoba
  class Account::Strategy::Base
    class NotSupportError < StandardError; end

    def self.build_account_by(attributes)
      raise NotImplementedError
    end

    def self.find_account_by(credentials)
      raise NotImplementedError
    end
  end
end
