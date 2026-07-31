# frozen_string_literal: true

module Aikotoba
  class Account::PasswordHash < ApplicationRecord
    LENGTH_RANGE = Aikotoba.password_length_range

    belongs_to :account, class_name: "Aikotoba::Account", foreign_key: "aikotoba_account_id", inverse_of: :password_hash

    # NOTE: No separate `validates :digest, presence: true`. `digest` only ever ends up
    #       blank as a direct side effect of `generate` being given a blank input, which
    #       always fails this same `plaintext` validation at the same time -- a digest
    #       presence check would only ever fire alongside this one, never independently.
    #       The DB's `null: false` constraint still guards against `digest` ending up nil
    #       through some other path.
    #
    # NOTE: Deliberately no `on:` restriction (used to be `on: [:create, :recover]`).
    #       Nested has_one/belongs_to autosave validation uses the parent's context when
    #       one is explicitly given (e.g. `save!(context: :recover)`), but otherwise
    #       validates an already-persisted child under its own natural `:update` context
    #       -- so a scoped `on:` here let `account.password_hash.generate("short");
    #       account.save` silently skip this validation entirely for any *existing*
    #       account (only `#recover!`'s explicit `context: :recover` caught it). Running
    #       unconditionally closes that gap; it's still cheap, because Rails only
    #       revalidates this record at all when it has pending changes to save (i.e. some
    #       code actually called `generate`) or a custom context was passed -- an
    #       untouched, already-persisted password_hash is never re-validated just because
    #       the parent account is saved for an unrelated reason.
    validates :plaintext, presence: true, length: {in: LENGTH_RANGE}

    def generate(input, pepper: Aikotoba.password_pepper, algorithm_class: Argon2)
      @plaintext = input
      self.digest = input.blank? ? "" : algorithm_class.new(password: with_pepper(input, pepper)).generate_hash
    end

    def match?(input, pepper: Aikotoba.password_pepper, algorithm_class: Argon2)
      algorithm_class.new(password: with_pepper(input, pepper)).verify_password?(digest)
    end

    def recover!(new_value)
      generate(new_value)
      save!(context: :recover)
    end

    class << self
      def authenticate_by(attributes:, target_type_name: nil)
        email, password = attributes.values_at(:email, :password)
        # NOTE: A blank password can never match anything, so there's nothing to guard
        #       against timing-wise here -- the caller already knows their own input was
        #       blank, and returning instantly regardless of account state leaks nothing.
        #       This also means `password` is guaranteed non-blank below, so it's safe to
        #       use as the dummy digest's seed (see prevent_timing_attack).
        return nil if password.blank?

        account = Account.find_by_identifier(email, target_type_name: target_type_name)

        matched = if account&.password_hash
          account.password_hash.match?(password)
        else
          # NOTE: Runs whether account is nil (not found) or exists but has no
          #       password_hash (e.g. a magic-link-only account), so neither case is
          #       distinguishable from a wrong-password guess by response time.
          prevent_timing_attack(password)
          false
        end
        return nil unless account

        ActiveRecord::Base.transaction do
          if matched
            account.authentication_success!
          else
            account.authentication_failed!
            Account::Lock.lock!(account: account, notify: true) if account.lockable? && account.should_lock?
          end
        end
        matched ? account : nil
      end

      private

      # NOTE: Seeds the dummy digest from the caller's own (guaranteed non-blank, per the
      #       guard in authenticate_by) password, so `generate` always pays full Argon2
      #       cost -- it only takes its blank-input shortcut for blank input, which can't
      #       reach here.
      def prevent_timing_attack(password)
        Account::PasswordHash.new.tap { |password_hash| password_hash.generate(password) }.match?(password)
      end
    end

    private

    attr_reader :plaintext

    def with_pepper(input, pepper)
      "#{input}-#{pepper}"
    end
  end
end
