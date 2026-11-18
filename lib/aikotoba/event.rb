# frozen_string_literal: true

module Aikotoba
  # NOTE: Every "aikotoba.<event>" structured event Aikotoba reports through Rails.event, one
  #       constant each: Event::SignInFailed.report(email: ..., account_id: ..., ...). Each
  #       is a Data class, so a missing or unknown payload key raises ArgumentError. Report
  #       them from the models and the sign in helpers rather than the controllers, so an
  #       app's own controller built on them reports the same events. Payloads hold plain
  #       values (ids, names), not records, since subscribers serialize them; they go to
  #       Rails.event as a Hash, which filter_parameters masks (an event object would not be).
  module Event
    # NOTE: after_commit: true (the default) is for something that happened (account_locked,
    #       ...): the event waits for every open transaction, the caller's included, to
    #       commit and is dropped on rollback, so a subscriber never hears about a change that
    #       didn't persist. It runs right away when no transaction is open. false is for an
    #       attempt that failed (sign_in_failed), which has nothing to commit.
    def self.define(name:, payload:, after_commit: true)
      Data.define(*payload) do
        # NOTE: Set here, inside the block, which can still see define's arguments; a def can't.
        @event_name = "aikotoba.#{name}"
        @after_commit = after_commit

        class << self
          attr_reader :event_name

          def after_commit?
            @after_commit
          end

          def report(**values)
            event = new(**values)
            if after_commit?
              ActiveRecord.after_all_transactions_commit { event.notify }
            else
              event.notify
            end
          end
        end

        def notify
          Rails.event.notify(self.class.event_name, to_h)
        end
      end
    end

    SignIn = define(name: :sign_in, payload: %i[account_id session_id scope])
    SignOut = define(name: :sign_out, payload: %i[account_id session_id scope])
    SignInFailed = define(name: :sign_in_failed, payload: %i[email account_id target_type_name], after_commit: false)
    # NOTE: A magic link that matches no active token for an account that can sign in to the scope:
    #       unknown, expired or already used. The token itself is a credential, so it is not reported.
    MagicLinkSignInFailed = define(name: :magic_link_sign_in_failed, payload: %i[target_type_name], after_commit: false)
    # NOTE: A one-time code that doesn't match the account's active code, or for which no
    #       active code is left (expired, or used up its attempts). The code is a credential,
    #       so it is not reported; the account is, since the password step already said whose it is.
    EmailOtpSignInFailed = define(name: :email_otp_sign_in_failed, payload: %i[account_id target_type_name], after_commit: false)
    AccountRegistered = define(name: :account_registered, payload: %i[account_id])
    AccountConfirmed = define(name: :account_confirmed, payload: %i[account_id])
    AccountLocked = define(name: :account_locked, payload: %i[account_id])
    AccountUnlocked = define(name: :account_unlocked, payload: %i[account_id])
    PasswordRecovered = define(name: :password_recovered, payload: %i[account_id])
    # NOTE: Reported for every token issued, with or without the email: notified says whether
    #       one was sent, since an app may issue a token itself (notify: false).
    ConfirmationTokenIssued = define(name: :confirmation_token_issued, payload: %i[account_id notified])
    UnlockTokenIssued = define(name: :unlock_token_issued, payload: %i[account_id notified])
    RecoveryTokenIssued = define(name: :recovery_token_issued, payload: %i[account_id notified])
    MagicLinkTokenIssued = define(name: :magic_link_token_issued, payload: %i[account_id notified])
    EmailOtpCodeIssued = define(name: :email_otp_code_issued, payload: %i[account_id notified])
  end
end
