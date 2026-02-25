# frozen_string_literal: true

module Aikotoba
  class Account::RefreshToken < ApplicationRecord
    include TokenEncryptable

    belongs_to :session, class_name: "Aikotoba::Account::Session", foreign_key: "aikotoba_account_session_id"

    validates :token, presence: true
    validates :expired_at, presence: true
    validate :session_must_be_api_origin

    scope :active, ->(now: Time.current) { where("expired_at >= ?", now) }

    after_initialize do |record|
      if record.token.nil? || record.expired_at.nil?
        token = Account::Token.new(expiry: Aikotoba.api_refresh_token_expiry)
        record.token ||= token.value
        record.expired_at ||= token.expired_at
      end
    end

    def active?(now: Time.current)
      expired_at >= now
    end

    def revoke!
      destroy!
    end

    def refresh!(**params)
      unless active?
        session.revoke!
        return nil
      end
      session.refresh!(**params)
    end

    class << self
      # TODO: Consider implementing Automatic Reuse Detection to enhance security features,
      #       and if a refresh token is reused, consider deleting the session associated with the account and forcing logout.
      #       https://auth0.com/blog/securing-single-page-applications-with-refresh-token-rotation/#Automatic-Reuse-Detection
      def refresh_session!(refresh_token_value:, **params)
        return nil if refresh_token_value.blank?
        refresh_token = find_by(token: refresh_token_value)
        return nil if refresh_token.nil?
        # NOTE: We need to lock the refresh token record to prevent concurrent refreshes with the same token,
        #       which could lead to multiple sessions being created.
        refresh_token.with_lock("FOR UPDATE NOWAIT") { refresh_token.refresh!(**params) }
      # NOTE: If the record is locked by another transaction, it means that a refresh is already in progress with the same token,
      #      so we return nil to indicate that the refresh failed.
      rescue ActiveRecord::LockWaitTimeout, ActiveRecord::RecordNotFound
        nil
      end
    end

    private

    def session_must_be_api_origin
      return if session.nil? || session.origin_api?
      errors.add(:session, :must_be_api_origin)
    end
  end
end
