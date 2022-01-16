# frozen_string_literal: true

require "aikotoba/version"
require "aikotoba/engine"

module Aikotoba
  mattr_accessor(:authenticate_account_method) { "current_user" }
  mattr_accessor(:authorize_account_method) { "authenticate_user!" }
  mattr_accessor(:session_key) { "aikotoba-user-id" }
  mattr_accessor(:prevent_timing_atack) { true }
  mattr_accessor(:password_pepper) { "aikotoba-default-pepper" }
  mattr_accessor(:password_stretch) { 2 }
  mattr_accessor(:password_minimum_length) { 8 }
  mattr_accessor(:sign_in_path) { "/sign_in" }
  mattr_accessor(:sign_up_path) { "/sign_up" }
  mattr_accessor(:sign_out_path) { "/sign_out" }
  mattr_accessor(:after_sign_in_path) { "/" }
  mattr_accessor(:after_sign_up_path) { "/sign_in" }
  mattr_accessor(:after_sign_out_path) { "/sign_in" }
  mattr_accessor(:appeal_sign_in_path) { "/sign_in" }

  # for confirmable
  mattr_accessor(:enable_confirm) { false }
  mattr_accessor(:confirm_path) { "/confirm" }

  # for lockable
  mattr_accessor(:enable_lock) { false }
  mattr_accessor(:unlock_path) { "/unlock" }
  mattr_accessor(:max_failed_attempts) { 10 }

  # for recoverable
  mattr_accessor(:enable_recover) { false }
  mattr_accessor(:recover_path) { "/recover" }
end
