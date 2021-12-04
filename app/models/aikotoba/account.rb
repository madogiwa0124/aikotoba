# frozen_string_literal: true

module Aikotoba
  class Account < ApplicationRecord
    belongs_to :authenticate_target, polymorphic: true, optional: true
    validates :password_digest, presence: true

    attribute :password, :string

    after_initialize do
      if authenticate_target
        target_type_name = authenticate_target_type.gsub("::", "").underscore
        define_singleton_method(target_type_name) { authenticate_target }
      end
    end

    def self.build_account_by(attributes, strategy: Strategy::PasswordOnly)
      strategy.build_account_by(attributes)
    end

    def self.find_account_by(credentials, strategy: Strategy::PasswordOnly)
      strategy.find_account_by(credentials)
    end
  end
end
