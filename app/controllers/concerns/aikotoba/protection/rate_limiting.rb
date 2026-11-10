# frozen_string_literal: true

# Rate limiting for the endpoints anyone can call repeatedly without an account: the
# token-sending endpoints (confirm, unlock, recover, magic link), against email bombing,
# and sign in / sign up, against credential stuffing and account enumeration.
# Uses Rails' built-in rate_limit feature.
#
# Usage:
#   class MyController < ApplicationController
#     include Protection::RateLimiting
#     aikotoba_rate_limit(Aikotoba.sign_in_rate_limit_options)
#   end
module Aikotoba
  module Protection::RateLimiting
    extend ActiveSupport::Concern

    module ClassMethods
      # NOTE: Applies one *_rate_limit_options setting. Empty options (the default) apply
      #       nothing. Without only:/except: it limits :create alone, so that showing the
      #       form, signing out and following a token link are never counted or blocked.
      #       scope: is fixed to this class's controller_path, so a host app's subclass
      #       counts against the same limit instead of getting its own (Rails reads
      #       controller_path per request, which a subclass changes).
      #       with: is left to Rails, so every endpoint raises TooManyRequests and the host
      #       app answers them all in one place (rescue_from or public/429.html).
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
