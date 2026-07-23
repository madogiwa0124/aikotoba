# frozen_string_literal: true

require "test_helper"

class Aikotoba::Account::PasswordTest < ActiveSupport::TestCase
  class ValueHandling < ActiveSupport::TestCase
    test "value= computes and stores a digest" do
      password = Aikotoba::Account::Password.new
      password.value = "Password1!"
      assert password.digest.present?
      refute_equal password.digest, "Password1!"
    end

    test "value reader returns the plaintext value" do
      password = Aikotoba::Account::Password.new
      password.value = "Password1!"
      assert_equal password.value, "Password1!"
    end
  end

  class MatchHandling < ActiveSupport::TestCase
    test "match? returns true for correct password" do
      account = Aikotoba::Account.create_by!(attributes: {
        email: "user@example.com",
        password: "Password1!"
      })
      assert account.password.match?("Password1!")
    end

    test "match? returns false for incorrect password" do
      account = Aikotoba::Account.create_by!(attributes: {
        email: "user@example.com",
        password: "Password1!"
      })
      refute account.password.match?("WrongPassword!")
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
      account = Aikotoba::Account::Password.authenticate_by(attributes: {
        email: "user@example.com",
        password: "Password1!"
      })
      assert_equal account, @account
    end

    test "authenticate_by returns nil for invalid email" do
      account = Aikotoba::Account::Password.authenticate_by(attributes: {
        email: "nonexistent@example.com",
        password: "Password1!"
      })
      assert_nil account
    end

    test "authenticate_by returns nil for invalid password" do
      account = Aikotoba::Account::Password.authenticate_by(attributes: {
        email: "user@example.com",
        password: "WrongPassword!"
      })
      assert_nil account
    end

    test "authenticate_by increments failed_attempts on invalid password" do
      initial_attempts = @account.failed_attempts
      Aikotoba::Account::Password.authenticate_by(attributes: {
        email: "user@example.com",
        password: "WrongPassword!"
      })
      assert_equal @account.reload.failed_attempts, initial_attempts + 1
    end

    test "authenticate_by resets failed_attempts on successful authentication" do
      @account.update!(failed_attempts: 5)
      Aikotoba::Account::Password.authenticate_by(attributes: {
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
      Aikotoba::Account::Password.authenticate_by(attributes: {
        email: "locktest@example.com",
        password: "WrongPassword!"
      })
      assert account.reload.locked?
      Aikotoba.lockable = false
    end
  end

  class Recoverable < ActiveSupport::TestCase
    test "recover! updates digest" do
      account = Aikotoba::Account.create_by!(attributes: {
        email: "user@example.com",
        password: "OldPassword1!"
      })
      old_digest = account.password.digest
      account.password.recover!("NewPassword1!")
      assert_not_equal account.reload.password.digest, old_digest
      assert account.password.match?("NewPassword1!")
    end

    test "recover! validates password length" do
      account = Aikotoba::Account.create_by!(attributes: {
        email: "user@example.com",
        password: "Password1!"
      })
      assert_raises(ActiveRecord::RecordInvalid) do
        account.password.recover!("short")
      end
    end
  end
end
