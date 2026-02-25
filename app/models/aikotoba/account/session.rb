# frozen_string_literal: true

module Aikotoba
  class Account::Session < ApplicationRecord
    include TokenEncryptable

    validates :token, presence: true
    validates :expired_at, presence: true

    enum :origin, {browser: "browser", api: "api"}, prefix: true

    belongs_to :account, class_name: "Aikotoba::Account", foreign_key: "aikotoba_account_id"
    has_one :refresh_token,
      class_name: "Aikotoba::Account::RefreshToken",
      dependent: :destroy,
      foreign_key: "aikotoba_account_session_id"

    scope :authenticatable, ->(target_type_name: nil) {
      joins(:account).merge(Account.authenticatable(target_type_name: target_type_name))
    }
    scope :active, ->(now: Time.current) { where("expired_at >= ?", now) }
    scope :api_origin, -> { where(origin: :api) }

    after_initialize do |record|
      if record.token.nil? || record.expired_at.nil?
        expiry = record.origin_api? ? Aikotoba.api_access_token_expiry : Aikotoba.session_expiry
        token = Account::Token.new(expiry: expiry)
        record.token ||= token.value
        record.expired_at ||= token.expired_at
      end
    end

    def revoke!
      destroy!
    end

    # NOTE: Even if the refresh token has remaining validity,
    #       we will suppress unauthorized use of the refresh token by deleting
    #       the session along with the refresh token at the time of refresh and issuing a new session.
    #       https://auth0.com/blog/securing-single-page-applications-with-refresh-token-rotation/#Introducing-Refresh-Token-Rotation
    def refresh!(**params)
      transaction do
        revoke!
        self.class.start!(account: account, **params)
      end
    end

    class << self
      def start!(account:, **params)
        session = account.sessions.new(
          origin: params[:origin] || "browser",
          expired_at: params[:expired_at],
          ip_address: params[:ip_address],
          user_agent: params[:user_agent]
        )
        # NOTE: For API sessions, both access token and refresh token are issued at the same time.
        session.build_refresh_token if session.origin_api?
        session.tap { |session| session.save! }
      end

      def find_by_token(token, target_type_name: nil, origin: "browser")
        active
          .authenticatable(target_type_name: target_type_name)
          .where(origin: origin)
          .find_by(token: token)
      end
    end
  end
end
