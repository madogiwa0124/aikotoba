# frozen_string_literal: true

module Aikotoba
  # NOTE: A second factor strategy (see Account::TwoFactor::Base for the interface): a short numeric
  #       code sent by email. Owns its own storage (Account::TwoFactor::EmailOtpCode) and the
  #       check, as Account::PasswordHash does for the first factor. Failed codes count towards the
  #       account's failed_attempts and lock it like a wrong password does, since whoever
  #       reaches this step already knows the password. The count is reset only when the
  #       session starts (Account::Session.start!), never by a correct password alone.
  class Account::TwoFactor::EmailOtp < Account::TwoFactor::Base
    # NOTE: Every account has an email address, so none has to set this up first.
    def self.enrollment_required?
      false
    end

    def self.create_code!(account:, notify: false)
      new(account: account).create_code!(notify: notify)
    end

    # NOTE: Always: there is nothing to set up (see enrollment_required?), and every account
    #       has the email address the code is sent to. Whether the account may still sign in
    #       (locked, another target type) is Account::TwoFactor's check, not this one.
    def usable?
      true
    end

    def start!
      create_code!(notify: true)
    end

    def challenge_expiry
      Aikotoba.email_otp_code_expiry
    end

    # NOTE: Read from the database rather than the association, which may hold a code
    #       authenticate has destroyed since.
    def challenge_active?
      Account::TwoFactor::EmailOtpCode.find_by(aikotoba_account_id: @account.id)&.active? || false
    end

    def create_code!(notify:)
      ActiveRecord::Base.transaction do
        @account.build_email_otp_code.save!
        @account.email_otp_code.notify if notify
        Event::EmailOtpCodeIssued.report(account_id: @account.id, notified: notify)
      end
    end

    # NOTE: code is what the user typed, checked against the issued EmailOtpCode. Whether the
    #       account may still sign in to the scope is Account::TwoFactor's check, made before
    #       this is called.
    #       The code row is locked (SELECT ... FOR UPDATE) before it is checked, so attempts
    #       against one code run one at a time: otherwise a burst of parallel guesses would all
    #       read the same attempt count and get past email_otp_max_failed_attempts together.
    #       The account is reloaded under that lock for the same reason (Lockable's count).
    def authenticate(code, target_type_name: nil)
      matched = ActiveRecord::Base.transaction do
        issued = Account::TwoFactor::EmailOtpCode.lock.find_by(aikotoba_account_id: @account.id)
        # NOTE: No code left to guess against (expired, used up, or never issued): fails
        #       without counting an attempt, so a user who comes back late isn't pushed
        #       towards a lock.
        next false unless issued&.active?

        @account.reload
        # NOTE: Leaves failed_attempts alone on a match: Account::Session.start! resets it once
        #       the account is actually signed in (see there).
        unless code.present? && issued.match?(code)
          failed!(issued)
          next false
        end

        issued.destroy!
        true
      end
      return true if matched

      Event::EmailOtpSignInFailed.report(account_id: @account.id, target_type_name: target_type_name)
      false
    end

    private

    # NOTE: A locked account can't finish signing in (Account::TwoFactor checks it can still
    #       sign in), so its code goes with the lock, and the sign in starts over.
    def failed!(issued)
      issued.increment!(:failed_attempts)
      authentication_failed!
      issued.destroy! if @account.locked? || !issued.active?
    end
  end
end
