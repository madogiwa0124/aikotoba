# frozen_string_literal: true

module Aikotoba
  # NOTE: An account's TOTP secret, shared with its authenticator app. Pending until the account
  #       turns it on with a code from the app (enabled_at), so a secret its app never stored
  #       can't lock it out. last_otp_at is the start of the time step of the last code
  #       accepted (like Rodauth's last_use), so a code is accepted once (RFC 6238 section 5.2).
  #
  #       TOTP itself is done by algorithm_class (TotpCredential::Algorithm, the rotp gem) and the QR
  #       code by qr_code_class (TotpCredential::QrCode, the rqrcode gem), which can be swapped
  #       per call like Account::PasswordHash's algorithm_class. This class references neither
  #       gem, so it loads without them.
  class Account::TwoFactor::TotpCredential < ApplicationRecord
    # NOTE: Accept a code from the time step before or after the current one too (30 seconds
    #       each way), for clocks that drift and codes typed just as they change.
    DRIFT = 30

    # NOTE: A Base32 string (RFC 4648), as authenticator apps expect, of 160 bits: the length
    #       RFC 4226 recommends for the shared secret (section 4, R6). Made with SecureRandom:
    #       the format is the RFC's, not a gem's.
    SECRET_ALPHABET = [*"A".."Z", *"2".."7"].freeze
    SECRET_LENGTH = 32

    def self.generate_secret
      Array.new(SECRET_LENGTH) { SECRET_ALPHABET[SecureRandom.random_number(SECRET_ALPHABET.size)] }.join
    end

    # NOTE: See Account::TwoFactor::EmailOtpCode: nested under a class that isn't a model.
    self.table_name = "aikotoba_account_totp_credentials"

    # NOTE: Encrypted, not hashed like a password: checking a code means computing
    #       HMAC(secret, time step) again, which needs the secret itself. Non-deterministic, as
    #       it is never looked up by value. Unlike a token it stays valid as long as TOTP is
    #       on, so Account::TwoFactor::Totp.validate_configuration! warns at boot without
    #       encrypted_token.
    encrypts :secret if Aikotoba.encrypted_token

    belongs_to :account, class_name: "Aikotoba::Account", foreign_key: "aikotoba_account_id"
    validates :secret, presence: true

    after_initialize do |record|
      record.secret ||= self.class.generate_secret
    end

    def enabled?
      enabled_at.present?
    end

    # NOTE: When the code verified, the start of the time step it belongs to (what last_otp_at
    #       records: the step, not the time of the request, since a code from the next step
    #       accepted now must stay used once that step comes), if it matches and is newer than
    #       the last one accepted; nil otherwise. Spaces are ignored ("123 456"), and nil is a mismatch.
    #       Doesn't record the step: the caller does, under its row lock, so two requests can't
    #       both use the same code.
    def verify(code, at: Time.current, algorithm_class: Algorithm)
      step = algorithm(algorithm_class).verify(code.to_s.gsub(/\s/, ""), drift: DRIFT, after: last_otp_at, at: at)
      step && Time.zone.at(step)
    end

    # NOTE: What the account's authenticator app reads from the QR code (otpauth://totp/...).
    def provisioning_uri(algorithm_class: Algorithm)
      algorithm(algorithm_class).provisioning_uri(account.email)
    end

    # NOTE: provisioning_uri as a QR code, an inline <svg> element. A plain string: the page
    #       decides to output it as HTML (raw), as TotpsController's does.
    def provisioning_qr_code_svg(algorithm_class: Algorithm, qr_code_class: QrCode)
      qr_code_class.new(data: provisioning_uri(algorithm_class: algorithm_class)).svg
    end

    private

    def algorithm(algorithm_class)
      algorithm_class.new(secret: secret, issuer: Aikotoba.totp_issuer || Rails.application.class.module_parent_name)
    end
  end
end
