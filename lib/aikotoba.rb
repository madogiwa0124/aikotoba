# frozen_string_literal: true

require "aikotoba/version"
require "aikotoba/engine"

module Aikotoba
  mattr_accessor(:authenticate_account_method) { "current_account" }
  mattr_accessor(:email_format) { /\A[^\s]+@[^\s]+\z/ }
  mattr_accessor(:password_pepper) { "aikotoba-default-pepper" }
  mattr_accessor(:password_minimum_length) { 8 }
  mattr_accessor(:session_key) { "aikotoba-account-id" }
  mattr_accessor(:sign_in_path) { "/sign_in" }
  mattr_accessor(:sign_out_path) { "/sign_out" }
  mattr_accessor(:after_sign_in_path) { "/" }
  mattr_accessor(:after_sign_out_path) { "/sign_in" }

  # for registerable
  mattr_accessor(:registerable) { true }
  mattr_accessor(:sign_up_path) { "/sign_up" }

  # for confirmable
  mattr_accessor(:confirmable) { false }
  mattr_accessor(:confirm_path) { "/confirm" }
  mattr_accessor(:confirmation_token_expiry) { 5.days }

  # for lockable
  mattr_accessor(:lockable) { false }
  mattr_accessor(:unlock_path) { "/unlock" }
  mattr_accessor(:max_failed_attempts) { 10 }
  mattr_accessor(:unlock_token_expiry) { 5.days }

  # for recoverable
  mattr_accessor(:recoverable) { false }
  mattr_accessor(:recover_path) { "/recover" }
  mattr_accessor(:recovery_token_expiry) { 5.days }

  # for security
  mattr_accessor(:prevent_timing_atack) { true }
end
