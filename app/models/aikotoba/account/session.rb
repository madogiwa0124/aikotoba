# frozen_string_literal: true

module Aikotoba
  class Account::Session < ApplicationRecord
    include TokenEncryptable

    validates :token, presence: true
    validates :expired_at, presence: true

    enum :origin, {browser: "browser", api: "api"}, prefix: true

    belongs_to :account, class_name: "Aikotoba::Account", foreign_key: "aikotoba_account_id"
    # NOTE: Not dependent: :destroy, for the reason spelled out in
    #       OptionalAssociation: aikotoba_account_refresh_tokens is optional, and an
    #       unconditional destroy callback queries it even when the host app never
    #       migrated it.
    #
    #       This is deliberately *not* that concern's `optional_has_one :refresh_token`,
    #       even though the macro works here and Account uses it for all four of its
    #       token associations.
    #       origin_api? is the exact mirror of the only place a refresh token is ever
    #       created (start! below builds one iff the session is api-origin), which makes
    #       it both cheaper and no less safe:
    #
    #       - Cheaper: a browser session issues zero queries against
    #         aikotoba_account_refresh_tokens. The concern would load the association on
    #         every sign-out just to find nothing, since it only skips when the table is
    #         absent, not when the row cannot exist.
    #       - No less safe: the concern's extra guard covers "an api session exists but
    #         its table doesn't", which start! makes unreachable -- session and refresh
    #         token are created in the same save, so no table means no api session
    #         either. Account has no equivalent invariant (an account legitimately has
    #         no token row), which is why it needs the table lookup and this doesn't.
    #
    #       Guarding on Aikotoba.api_authenticatable instead would be worse than both:
    #       switching the flag off with api sessions still around strands their refresh
    #       tokens and raises ActiveRecord::InvalidForeignKey on Session#destroy.
    has_one :refresh_token,
      class_name: "Aikotoba::Account::RefreshToken",
      foreign_key: "aikotoba_account_session_id"
    before_destroy { refresh_token&.destroy if origin_api? }

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
