# frozen_string_literal: true

module Aikotoba
  # NOTE: A second factor strategy (see Account::TwoFactor::Base for the interface): a code from an
  #       authenticator app holding a secret shared with the account (RFC 6238 TOTP). An account
  #       sets it up first (enroll!, then enable! with a code from the app); until then it
  #       can't use it, and the scope's next strategy is used instead.
  #
  #       Nothing is sent: start! does nothing, and the code the app shows is checked against
  #       the account's secret. Wrong codes count towards failed_attempts and lock the account
  #       with Lockable, as a wrong password does; there is no per-challenge limit, since a TOTP
  #       code has no row of its own to count on.
  class Account::TwoFactor::Totp < Account::TwoFactor::Base
    class << self
      def enrollment_required?
        true
      end

      # NOTE: Warns, at boot, about the one mistake nothing else would show: without
      #       encrypted_token the secrets are stored in plain text, and nothing fails until the
      #       table leaks, when every account's codes can be computed. Missing gems aren't
      #       checked: the set up page fails right away with a LoadError naming them.
      def validate_configuration!(scope_names)
        return if Aikotoba.encrypted_token

        Aikotoba.logger.warn(
          "TOTP is offered (#{scope_names.join(", ")}) but encrypted_token is off, so TOTP secrets are stored " \
          "in plain text: anyone who reads the table can compute every account's codes. Turn on " \
          "config.encrypted_token (Active Record Encryption)."
        )
      end
    end

    def usable?
      credential&.enabled? || false
    end

    # NOTE: Nothing to send: the authenticator app already shows the code.
    def start!
    end

    def challenge_expiry
      Aikotoba.totp_challenge_expiry
    end

    # NOTE: There's no code to run out of, so the sign in can go on while TOTP is still set up.
    def challenge_active?
      usable?
    end

    # NOTE: The credential row is locked while the code is checked and its time step recorded,
    #       so two requests can't both use the same code, and the account is reloaded under that
    #       lock for Lockable's count. Whether the account may still sign in to the scope is
    #       Account::TwoFactor's check, made before this is called.
    def authenticate(code, target_type_name: nil)
      matched = ActiveRecord::Base.transaction do
        locked = locked_credential
        next false unless locked&.enabled?

        @account.reload
        # NOTE: Leaves failed_attempts alone on a match: Account::Session.start! resets it once
        #       the account is actually signed in (see there).
        verified_at = locked.verify(code)
        unless verified_at
          authentication_failed!
          next false
        end

        locked.update!(last_otp_at: verified_at)
        true
      end
      return true if matched

      Event::TotpSignInFailed.report(account_id: @account.id, target_type_name: target_type_name)
      false
    end

    # NOTE: Setting up, for the account itself (TotpsController) or an app's own page. Returns
    #       the pending credential to show (provisioning_uri for the QR code), creating one if
    #       there isn't, or nil once TOTP is already set up. Showing the page again keeps the
    #       same secret, so a QR code being scanned stays valid.
    #       Inserted directly, not through build_totp_credential: the has_one builder destroys
    #       an existing row to replace it, so of two requests showing the page at once (a double
    #       click) the second would silently swap the secret the first one is showing. Instead
    #       the second raises ActiveRecord::RecordNotUnique on the unique index, rolling back
    #       its transaction like any other failed write, and showing the page again shows the
    #       first one's secret.
    def enroll!
      existing = credential
      return if existing&.enabled?
      return existing if existing

      Account::TwoFactor::TotpCredential.create!(account: @account).tap { reset_association }
    end

    # NOTE: Turns TOTP on once the account proves its app holds the pending secret. A wrong code
    #       here doesn't count as a failed sign in: the secret protects nothing yet.
    def enable!(code)
      ActiveRecord::Base.transaction do
        locked = locked_credential
        next false if locked.nil? || locked.enabled?

        verified_at = locked.verify(code)
        next false unless verified_at

        locked.update!(enabled_at: Time.current, last_otp_at: verified_at)
        Event::TotpEnabled.report(account_id: @account.id)
        true
      end
    end

    # NOTE: For the account itself: needs a current code, like a sign in, and a wrong one counts
    #       as a failed sign in, since whoever holds the session may not be the account's owner.
    def disable_with!(code)
      ActiveRecord::Base.transaction do
        locked = locked_credential
        next false unless locked&.enabled?

        @account.reload
        unless locked.verify(code)
          authentication_failed!
          next false
        end

        remove!(locked)
        true
      end
    end

    # NOTE: No code, hence force: for an app's own admin page, or support, when the account lost
    #       its device, after the app checked it is them.
    #       Removes a pending secret too. false when there was none, true once removed.
    def force_disable!
      ActiveRecord::Base.transaction do
        locked = locked_credential
        next false unless locked

        remove!(locked)
        true
      end
    end

    def credential
      Account::TwoFactor::TotpCredential.find_by(aikotoba_account_id: @account.id)
    end

    private

    def locked_credential
      Account::TwoFactor::TotpCredential.lock.find_by(aikotoba_account_id: @account.id)
    end

    def remove!(record)
      record.destroy!
      reset_association
      Event::TotpDisabled.report(account_id: @account.id) if record.enabled?
    end

    # NOTE: The credential is written without going through @account's totp_credential, so
    #       forget what that association may have loaded. Otherwise the same account object
    #       would keep a stale nil, and Account#destroy! (whose cleanup reads the association)
    #       would leave the row behind and fail on its foreign key.
    def reset_association
      @account.association(:totp_credential).reset
    end
  end
end
