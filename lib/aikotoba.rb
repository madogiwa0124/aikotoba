# frozen_string_literal: true

require "aikotoba/version"
require "aikotoba/engine"

module Aikotoba
  mattr_accessor(:authenticate_class) { "User" }
  mattr_accessor(:session_key) { "aikotoba-user-id" }
  mattr_accessor(:secret_generator) { -> { SecureRandom.hex(16) } }
  mattr_accessor(:secret_papper) { "aikotoba-default-pepper" }
  mattr_accessor(:secret_stretch) { 3 }
  mattr_accessor(:secret_digest_generator) { ->(secret) { Digest::SHA256.hexdigest(secret) } }
  mattr_accessor(:sign_in_path) { "/sign_in" }
  mattr_accessor(:sign_up_path) { "/sign_up" }
  mattr_accessor(:sign_out_path) { "/sign_out" }
  mattr_accessor(:after_sign_in_path) { "/" }
  mattr_accessor(:failured_sign_in_path) { "/sign_in" }
  mattr_accessor(:after_sign_up_path) { "/sign_in" }
  mattr_accessor(:after_sign_out_path) { "/sign_in" }
end
