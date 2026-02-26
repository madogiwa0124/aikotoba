# frozen_string_literal: true

module Aikotoba
  module Api
    class Token
      def initialize(access_token:, refresh_token:, expired_at:)
        @access_token = access_token
        @refresh_token = refresh_token
        @expired_at = expired_at
      end

      attr_reader :access_token, :refresh_token, :expired_at

      def to_h
        {
          access_token: access_token,
          token_type: "Bearer",
          expires_in: expired_in,
          refresh_token: refresh_token
        }.compact
      end

      private

      def expired_in
        [(expired_at - Time.current).to_i, 0].max
      end
    end
  end
end
