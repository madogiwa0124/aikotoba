# frozen_string_literal: true

require "test_helper"

class Aikotoba::Account::PasswordHashTest < ActiveSupport::TestCase
  class GenerateHandling < ActiveSupport::TestCase
    test "generate computes and stores a digest" do
      password_hash = Aikotoba::Account::PasswordHash.new
      password_hash.generate("Password1!")
      assert password_hash.digest.present?
      refute_equal password_hash.digest, "Password1!"
    end

    test "generate on an existing account still validates when saved through the parent" do
      # NOTE: regression guard -- has_one autosave validates an already-persisted nested
      #       record under its own natural :update context when the parent save doesn't
      #       pass a custom context. The validation used to be scoped `on: [:create,
      #       :recover]`, so this exact path (generate + plain account.save, not
      #       #recover!) silently skipped it and persisted an invalid password.
      account = Aikotoba::Account.create_by!(attributes: {email: "user@example.com", password: "Password1!"})
      account.password_hash.generate("short")
      refute account.save
      assert_includes account.errors.full_messages, "Password is too short (minimum is 8 characters)"
      refute account.reload.password_hash.match?("short")
    end
  end

  class MatchHandling < ActiveSupport::TestCase
    test "match? returns true for correct password" do
      account = Aikotoba::Account.create_by!(attributes: {
        email: "user@example.com",
        password: "Password1!"
      })
      assert account.password_hash.match?("Password1!")
    end

    test "match? returns false for incorrect password" do
      account = Aikotoba::Account.create_by!(attributes: {
        email: "user@example.com",
        password: "Password1!"
      })
      refute account.password_hash.match?("WrongPassword!")
    end
  end

  class AuthenticateBy < ActiveSupport::TestCase
    def setup
      @account = Aikotoba::Account.create_by!(attributes: {
        email: "user@example.com",
        password: "Password1!",
        confirmed: true,
        locked: false,
        failed_attempts: 0
      })
    end

    test "authenticate_by returns account for valid credentials" do
      account = Aikotoba::Account::PasswordHash.authenticate_by(attributes: {
        email: "user@example.com",
        password: "Password1!"
      })
      assert_equal account, @account
    end

    test "authenticate_by returns nil for invalid email" do
      account = Aikotoba::Account::PasswordHash.authenticate_by(attributes: {
        email: "nonexistent@example.com",
        password: "Password1!"
      })
      assert_nil account
    end

    test "authenticate_by returns nil for invalid password" do
      account = Aikotoba::Account::PasswordHash.authenticate_by(attributes: {
        email: "user@example.com",
        password: "WrongPassword!"
      })
      assert_nil account
    end

    test "authenticate_by increments failed_attempts on invalid password" do
      initial_attempts = @account.failed_attempts
      Aikotoba::Account::PasswordHash.authenticate_by(attributes: {
        email: "user@example.com",
        password: "WrongPassword!"
      })
      assert_equal @account.reload.failed_attempts, initial_attempts + 1
    end

    test "authenticate_by resets failed_attempts on successful authentication" do
      @account.update!(failed_attempts: 5)
      Aikotoba::Account::PasswordHash.authenticate_by(attributes: {
        email: "user@example.com",
        password: "Password1!"
      })
      assert_equal @account.reload.failed_attempts, 0
    end

    test "authenticate_by locks account when max attempts exceeded" do
      Aikotoba.lockable = true
      account = Aikotoba::Account.create_by!(attributes: {
        email: "locktest@example.com",
        password: "Password1!",
        confirmed: true,
        locked: false,
        failed_attempts: 10
      })
      Aikotoba::Account::PasswordHash.authenticate_by(attributes: {
        email: "locktest@example.com",
        password: "WrongPassword!"
      })
      assert account.reload.locked?
      Aikotoba.lockable = false
    end

    test "authenticate_by returns nil without raising for an account with no password_hash" do
      passwordless = Aikotoba::Account.create_by!(attributes: {email: "no-password@example.com"})
      account = Aikotoba::Account::PasswordHash.authenticate_by(attributes: {
        email: "no-password@example.com",
        password: "WhateverPassword1!"
      })
      assert_nil account
      assert_equal passwordless.reload.failed_attempts, 1
    end

    test "authenticate_by returns nil for a blank password without touching the account" do
      # NOTE: a blank password can never match, so authenticate_by short-circuits before
      #       even looking up the account -- this guards against that path
      #       misbehaving/raising, and confirms it deliberately skips failed_attempts
      #       bookkeeping (the caller already knows their own input was blank).
      account = Aikotoba::Account::PasswordHash.authenticate_by(attributes: {
        email: "nonexistent@example.com",
        password: ""
      })
      assert_nil account

      account = Aikotoba::Account::PasswordHash.authenticate_by(attributes: {
        email: "user@example.com",
        password: ""
      })
      assert_nil account
      assert_equal @account.reload.failed_attempts, 0
    end
  end

  class Recoverable < ActiveSupport::TestCase
    test "recover! updates digest" do
      account = Aikotoba::Account.create_by!(attributes: {
        email: "user@example.com",
        password: "OldPassword1!"
      })
      old_digest = account.password_hash.digest
      account.password_hash.recover!("NewPassword1!")
      assert_not_equal account.reload.password_hash.digest, old_digest
      assert account.password_hash.match?("NewPassword1!")
    end

    test "recover! validates password length" do
      account = Aikotoba::Account.create_by!(attributes: {
        email: "user@example.com",
        password: "Password1!"
      })
      assert_raises(ActiveRecord::RecordInvalid) do
        account.password_hash.recover!("short")
      end
    end
  end
end
