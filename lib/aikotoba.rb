# frozen_string_literal: true

require "aikotoba/version"
require "aikotoba/engine"

module Aikotoba
  mattr_accessor(:authenticate_account_method) { "current_user" }
  mattr_accessor(:authorize_account_method) { "authenticate_user!" }
  mattr_accessor(:session_key) { "aikotoba-user-id" }
  mattr_accessor(:prevent_timing_atack) { true }
  mattr_accessor(:password_generator) { -> { SecureRandom.hex(16) } }
  mattr_accessor(:password_papper) { "aikotoba-default-pepper" }
  mattr_accessor(:password_stretch) { 3 }
  mattr_accessor(:password_digest_generator) { ->(password) { Digest::SHA256.hexdigest(password) } }
  mattr_accessor(:sign_in_path) { "/sign_in" }
  mattr_accessor(:sign_up_path) { "/sign_up" }
  mattr_accessor(:sign_out_path) { "/sign_out" }
  mattr_accessor(:after_sign_in_path) { "/" }
  mattr_accessor(:failed_sign_in_path) { "/sign_in" }
  mattr_accessor(:after_sign_up_path) { "/sign_in" }
  mattr_accessor(:after_sign_out_path) { "/sign_in" }
  mattr_accessor(:appeal_sign_in_path) { "/sign_in" }
end
