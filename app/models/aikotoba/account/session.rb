# frozen_string_literal: true

module Aikotoba
  class Account::Session < ApplicationRecord
    include TokenEncryptable

    validates :token, presence: true
    validates :expired_at, presence: true

    belongs_to :account, class_name: "Aikotoba::Account", foreign_key: "aikotoba_account_id"

    scope :authenticatable, ->(target_type_name: nil) {
      joins(:account).merge(Account.authenticatable(target_type_name: target_type_name))
    }
    scope :active, ->(now: Time.current) { where("expired_at >= ?", now) }

    after_initialize do |record|
      token = Account::Token.new(expiry: Aikotoba.session_expiry)
      record.token ||= token.value
      record.expired_at ||= token.expired_at
    end

    def revoke!
      destroy!
    end

    class << self
      def start!(account:, **params)
        account.sessions.create!(
          ip_address: params[:ip_address],
          user_agent: params[:user_agent]
        )
      end

      def find_by_token(token, target_type_name: nil)
        active.authenticatable(target_type_name: target_type_name).find_by(token: token)
      end
    end
  end
end
