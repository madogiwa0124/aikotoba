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

  # for Registerable
  mattr_accessor(:registerable) { true }

  # for Confirmable
  mattr_accessor(:confirmable) { false }
  mattr_accessor(:confirmation_token_expiry) { 1.day }

  # for Lockable
  mattr_accessor(:lockable) { false }
  mattr_accessor(:max_failed_attempts) { 10 }
  mattr_accessor(:unlock_token_expiry) { 1.day }

  # for Recoverable
  mattr_accessor(:recoverable) { false }
  mattr_accessor(:recovery_token_expiry) { 4.hours }

  # for encrypt token
  mattr_accessor(:encypted_token) { false }

  mattr_accessor(:namespaces) {
    {
      default: {
        root_path: "/",
        as: "aikotoba",
        session_key: "aikotoba-account-id",
        sign_in_path: "/sign_in",
        sign_out_path: "/sign_out",
        after_sign_in_path: "/",
        after_sign_out_path: "/sign_in",
        sign_up_path: "/sign_up",
        confirm_path: "/confirm",
        unlock_path: "/unlock",
        recover_path: "/recover"
      }
    }
  }

  namespaces[:default].each do |key, value|
    mattr_accessor(key) { value }
  end

  def self.add_namespace(name, config = {})
    namespaces[name] = namespaces[:default].merge(config)
  end
end
