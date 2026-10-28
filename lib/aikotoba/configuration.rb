# frozen_string_literal: true

require "active_support/core_ext/object/deep_dup"
require "active_support/core_ext/integer/time"
require "aikotoba/scopes"

module Aikotoba
  # NOTE: Every setting, set through Aikotoba.configure and read through Aikotoba.xxx.
  class Configuration
    SETTINGS = %i[
      parent_controller parent_mailer mailer_sender email_format password_pepper
      password_length_range session_expiry
      registerable
      confirmable confirmation_token_expiry confirmation_rate_limit_options
      lockable max_failed_attempts unlock_token_expiry unlock_rate_limit_options
      recoverable recovery_token_expiry recovery_rate_limit_options
      magic_link_authenticatable magic_link_token_expiry magic_link_rate_limit_options
      encrypted_token
      scopes
    ].freeze

    attr_accessor(*SETTINGS)

    def initialize
      @parent_controller = "ApplicationController"
      @parent_mailer = "ActionMailer::Base"
      @mailer_sender = "from@example.com"
      @email_format = /\A[^\s]+@[^\s]+\z/
      @password_pepper = "aikotoba-default-pepper"
      @password_length_range = 8..100
      @session_expiry = 7.days

      # for Registerable
      @registerable = true

      # for Confirmable
      @confirmable = false
      @confirmation_token_expiry = 1.day
      @confirmation_rate_limit_options = {}

      # for Lockable
      @lockable = false
      @max_failed_attempts = 10
      @unlock_token_expiry = 1.day
      @unlock_rate_limit_options = {}

      # for Recoverable
      @recoverable = false
      @recovery_token_expiry = 4.hours
      @recovery_rate_limit_options = {}

      # for MagicLinkAuthenticatable
      @magic_link_authenticatable = false
      @magic_link_token_expiry = 15.minutes
      @magic_link_rate_limit_options = {}

      # for encrypt token
      @encrypted_token = false

      @scopes = Scopes.new({
        default: {
          authenticate_for: nil,
          root_path: "/",
          session_key: "aikotoba_session_token",
          sign_in_path: "/sign_in",
          sign_out_path: "/sign_out",
          after_sign_in_path: "/",
          after_sign_out_path: "/sign_in",
          sign_up_path: "/sign_up",
          confirm_path: "/confirm",
          unlock_path: "/unlock",
          recover_path: "/recover",
          magic_link_path: "/magic_link"
        }
      })
    end

    # NOTE: A copy shares nothing with the original, so changing one (scopes, rate limit
    #       options) leaves the other as it was.
    def initialize_copy(source)
      super
      SETTINGS.each { |name| public_send(:"#{name}=", source.public_send(name).deep_dup) }
    end

    def default_scope
      scopes.default_scope
    end

    # NOTE: Merges into the default scope (does not replace, keeps the other keys).
    #       Example: config.default_scope = { sign_in_path: "/custom" }
    def default_scope=(hash)
      default_scope.merge!(hash)
    end

    def add_scope(name, config = {})
      scopes.add(name, config)
    end
  end
end
