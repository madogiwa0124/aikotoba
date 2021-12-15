# frozen_string_literal: true

module Aikotoba
  class Account::Strategy::Base
    def self.build_account_by(attributes)
      raise NotImplementedError
    end

    def self.find_account_by(credentials)
      raise NotImplementedError
    end

    def self.confirmable?
      raise NotImplementedError
    end
  end
end
