# frozen_string_literal: true

module Aikotoba
  # NOTE: A second factor strategy (see Account::TwoFactor for the interface): a short numeric
  #       code sent by email. Owns its own storage (Account::TwoFactor::EmailOtpCode) and the check, as
  #       Account::PasswordHash does for the first factor. Failed codes count towards the
  #       account's failed_attempts and lock it like a wrong password does, since whoever
  #       reaches this step already knows the password.
  class Account::TwoFactor::EmailOtp
    def self.create_code!(account:, notify: false)
      new(account: account).create_code!(notify: notify)
    end

    def initialize(account:)
      @account = account
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

    # NOTE: response is the code the user typed. Whether the account may still sign in to the
    #       scope is Account::TwoFactor's check, made before this is called.
    #       The code row is locked (SELECT ... FOR UPDATE) before it is checked, so attempts
    #       against one code run one at a time: otherwise a burst of parallel guesses would all
    #       read the same attempt count and get past email_otp_max_failed_attempts together.
    #       The account is reloaded under that lock for the same reason (Lockable's count).
    def authenticate(response, target_type_name: nil)
      result = ActiveRecord::Base.transaction do
        code = Account::TwoFactor::EmailOtpCode.lock.find_by(aikotoba_account_id: @account.id)
        # NOTE: No code left to guess against (expired, used up, or never issued): fails
        #       without counting an attempt, so a user who comes back late isn't pushed
        #       towards a lock.
        next :no_code unless code&.active?

        @account.reload
        if response.present? && code.match?(response)
          @account.authentication_success!
          code.destroy!
          :matched
        else
          failed!(code)
          :failed
        end
      end
      (result == :matched) ? @account : sign_in_failed(target_type_name)
    end

    private

    # NOTE: A locked account can't finish signing in (Account::TwoFactor checks it can still
    #       sign in), so its code goes with the lock, and the sign in starts over.
    def failed!(code)
      @account.authentication_failed!
      code.increment!(:failed_attempts)
      if @account.lockable? && @account.should_lock?
        Account::Lock.lock!(account: @account, notify: true)
        code.destroy!
      elsif !code.active?
        code.destroy!
      end
    end

    def sign_in_failed(target_type_name)
      Event::EmailOtpSignInFailed.report(account_id: @account.id, target_type_name: target_type_name)
      nil
    end
  end
end
