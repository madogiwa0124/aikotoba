# frozen_string_literal: true

module Aikotoba
  # NOTE: The second factor of a password sign in to a scope with two_factor_authenticatable:
  #       a short numeric code sent by email. Owns its own storage (Account::EmailOtpCode) and
  #       the check, as Account::PasswordHash does for the first factor. Failed codes count
  #       towards the account's failed_attempts and lock it like a wrong password does, since
  #       whoever reaches this step already knows the password.
  class Account::EmailOtp
    def self.create_code!(account:, notify: false)
      new(account: account).create_code!(notify: notify)
    end

    # NOTE: account_id comes from the sign in in progress (the Rails session), not from the
    #       user. The account is looked up through authenticatable again, so one locked (or
    #       otherwise unable to sign in) since the password step can't finish signing in.
    def self.authenticate_by(account_id:, code:, target_type_name: nil)
      account = Account.authenticatable(target_type_name: target_type_name).find_by(id: account_id)
      return unless account

      new(account: account).authenticate(code, target_type_name: target_type_name)
    end

    # NOTE: Whether the sign in can still be finished with a code: the account can still sign
    #       in to the scope (not locked since, say) and has a code left to try (not expired or
    #       used up). Once not, the sign in has to start over from the password.
    def self.code_active?(account_id:, target_type_name: nil)
      account = Account.authenticatable(target_type_name: target_type_name).find_by(id: account_id)
      account&.email_otp_code&.active? || false
    end

    def initialize(account:)
      @account = account
    end

    def create_code!(notify:)
      ActiveRecord::Base.transaction do
        @account.build_email_otp_code.save!
        @account.email_otp_code.notify if notify
        Event::EmailOtpCodeIssued.report(account_id: @account.id, notified: notify)
      end
    end

    # NOTE: The code row is locked (SELECT ... FOR UPDATE) before it is checked, so attempts
    #       against one code run one at a time: otherwise a burst of parallel guesses would all
    #       read the same attempt count and get past email_otp_max_failed_attempts together.
    #       The account is reloaded under that lock for the same reason (Lockable's count).
    def authenticate(input, target_type_name: nil)
      result = ActiveRecord::Base.transaction do
        code = Account::EmailOtpCode.lock.find_by(aikotoba_account_id: @account.id)
        # NOTE: No code left to guess against (expired, used up, or never issued): fails
        #       without counting an attempt, so a user who comes back late isn't pushed
        #       towards a lock.
        next :no_code unless code&.active?

        @account.reload
        if input.present? && code.match?(input)
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

    # NOTE: A locked account can't finish signing in (authenticate_by looks it up through
    #       authenticatable), so its code goes with the lock, and the sign in starts over.
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
