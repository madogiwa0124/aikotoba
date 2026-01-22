# frozen_string_literal: true

# Rate limiting protection for email-sending endpoints to prevent email bombing attacks.
# Requires Rails 8+ to use the built-in rate_limit feature.
#
# Usage:
#   class MyController < ApplicationController
#     include Protection::RateLimiting
#     rate_limit(to: 10, within: 1.minute, by: -> { request.remote_ip })
#   end
module Aikotoba
  module Protection::RateLimiting
    extend ActiveSupport::Concern

    module ClassMethods
      def rate_limit(**options)
        return if options.empty? # Allow empty config (disabled by default)

        if available_rails_rate_limiting?
          super
        else
          raise Errors::NotAvailableException,
            "Rate limiting requires Rails 8+. Current version: #{Rails::VERSION::STRING}"
        end
      end

      def available_rails_rate_limiting?
        Rails::VERSION::MAJOR >= 8
      end
    end
  end
end
