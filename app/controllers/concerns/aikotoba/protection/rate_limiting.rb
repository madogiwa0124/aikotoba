# frozen_string_literal: true

# Rate limiting protection for email-sending endpoints to prevent email bombing attacks.
# Uses Rails' built-in rate_limit feature.
#
# Usage:
#   class MyController < ApplicationController
#     include Protection::RateLimiting
#     aikotoba_rate_limit(Aikotoba.confirmation_rate_limit_options)
#   end
module Aikotoba
  module Protection::RateLimiting
    extend ActiveSupport::Concern

    module ClassMethods
      # NOTE: Applies one *_rate_limit_options setting. Empty options (the default) apply
      #       nothing. Without only:/except: it limits :create alone, so that showing the
      #       form and following a token link are never counted or blocked.
      #       scope: is fixed to this class's controller_path, so a host app's subclass
      #       counts against the same limit instead of getting its own (Rails reads
      #       controller_path per request, which a subclass changes).
      def aikotoba_rate_limit(options)
        return if options.empty?

        options = options.dup
        options[:only] = :create unless options.key?(:only) || options.key?(:except)
        options[:scope] = controller_path unless options.key?(:scope)
        rate_limit(**options)
      end

      def rate_limit(**options)
        return if options.empty? # Allow empty config (disabled by default)

        super
      end
    end
  end
end
