# frozen_string_literal: true

require "aikotoba/version"
require "aikotoba/engine"
require "aikotoba/errors"

module Aikotoba
  mattr_accessor(:parent_controller) { "ApplicationController" }
  mattr_accessor(:parent_mailer) { "ActionMailer::Base" }
  mattr_accessor(:mailer_sender) { "from@example.com" }
  mattr_accessor(:email_format) { /\A[^\s]+@[^\s]+\z/ }
  mattr_accessor(:password_pepper) { "aikotoba-default-pepper" }
  mattr_accessor(:password_length_range) { 8..100 }
  mattr_accessor(:session_expiry) { 7.days }

  # for API Token Authentication
  mattr_accessor(:api_authenticatable) { false }
  mattr_accessor(:api_parent_controller) { "ApplicationController" }
  mattr_accessor(:api_access_token_expiry) { 15.minutes }
  mattr_accessor(:api_refresh_token_expiry) { 30.days }

  # for Registerable
  mattr_accessor(:registerable) { true }

  # for Confirmable
  mattr_accessor(:confirmable) { false }
  mattr_accessor(:confirmation_token_expiry) { 1.day }
  mattr_accessor(:confirmation_rate_limit_options) { {} }

  # for Lockable
  mattr_accessor(:lockable) { false }
  mattr_accessor(:max_failed_attempts) { 10 }
  mattr_accessor(:unlock_token_expiry) { 1.day }
  mattr_accessor(:unlock_rate_limit_options) { {} }

  # for Recoverable
  mattr_accessor(:recoverable) { false }
  mattr_accessor(:recovery_token_expiry) { 4.hours }
  mattr_accessor(:recovery_rate_limit_options) { {} }

  # for MagicLinkAuthenticatable
  mattr_accessor(:magic_link_authenticatable) { false }
  mattr_accessor(:magic_link_token_expiry) { 15.minutes }
  mattr_accessor(:magic_link_rate_limit_options) { {} }

  # for encrypt token
  mattr_accessor(:encrypted_token) { false }

  mattr_accessor(:scopes) {
    HashWithIndifferentAccess.new({
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
        magic_link_path: "/magic_link",
        api_sign_in_path: "/api/sessions",
        api_refresh_path: "/api/sessions/refresh",
        api_sign_out_path: "/api/sessions/current"
      }
    })
  }

  def self.default_scope
    scopes[:default]
  end

  # NOTE: Merge configuration into default scope (does not replace, merges with existing keys)
  #       Example: Aikotoba.default_scope = { sign_in_path: "/custom" }
  def self.default_scope=(hash)
    default_scope.merge!(hash)
  end

  def self.add_scope(name, config = {})
    scopes[name] = default_scope.merge(config)
  end

  # NOTE: A scope restricted by authenticate_for gets no sign-up: its accounts need an
  #       authenticate_target of that type, which the generic sign-up form can't create.
  #       Routes and the sign-in page's sign-up link both read this, so they can't disagree.
  def self.registerable_scope?(scope_config)
    scope_config[:authenticate_for].nil?
  end
end
