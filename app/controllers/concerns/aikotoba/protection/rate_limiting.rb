# frozen_string_literal: true

# Rate limiting protection for email-sending endpoints to prevent email bombing attacks.
# Uses Rails' built-in rate_limit feature.
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

        super
      end
    end
  end
end
