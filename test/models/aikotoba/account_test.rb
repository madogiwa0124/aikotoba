# frozen_string_literal: true

require "test_helper"

class Aikotoba::AccountTest < ActiveSupport::TestCase
  class PasswordHandling < ActiveSupport::TestCase
    test "password assignment sets password_digest" do
      account = Aikotoba::Account.new(email: "user@example.com")
      account.password = "Password1!"
      assert account.password_digest.present?
      refute_equal account.password_digest, "Password1!"
    end

    test "password reader returns password value" do
      account = Aikotoba::Account.new(email: "user@example.com")
      account.password = "Password1!"
      assert_equal account.password, "Password1!"
    end

    test "password_match? returns true for correct password" do
      account = Aikotoba::Account.create!(
        email: "user@example.com",
        password: "Password1!"
      )
      assert account.password_match?("Password1!")
    end

    test "password_match? returns false for incorrect password" do
      account = Aikotoba::Account.create!(
        email: "user@example.com",
        password: "Password1!"
      )
      refute account.password_match?("WrongPassword!")
    end
  end

  class Registrable < ActiveSupport::TestCase
    test "build_by creates account with email and password" do
      account = Aikotoba::Account.build_by(attributes: {
        email: "user@example.com",
        password: "Password1!"
      })
      assert account.email == "user@example.com"
      assert account.password_digest.present?
    end

    test "register! saves account" do
      account = Aikotoba::Account.build_by(attributes: {
        email: "user@example.com",
        password: "Password1!"
      })
      assert_difference "Aikotoba::Account.count", 1 do
        account.register!
      end
      assert account.persisted?
    end

    test "register! creates confirmation token when confirmable" do
      Aikotoba.confirmable = true
      account = Aikotoba::Account.build_by(attributes: {
        email: "user@example.com",
        password: "Password1!"
      })
      assert_difference "Aikotoba::Account::ConfirmationToken.count", 1 do
        account.register!
      end
      Aikotoba.confirmable = false
    end

    test "register! does not create confirmation token when not confirmable" do
      Aikotoba.confirmable = false
      account = Aikotoba::Account.build_by(attributes: {
        email: "user@example.com",
        password: "Password1!"
      })
      assert_no_difference "Aikotoba::Account::ConfirmationToken.count" do
        account.register!
      end
    end
  end

  class Authenticatable < ActiveSupport::TestCase
    def setup
      @account = Aikotoba::Account.create!(
        email: "user@example.com",
        password: "Password1!",
        confirmed: true,
        locked: false,
        failed_attempts: 0
      )
    end

    test "authenticate returns account for correct password" do
      result = @account.authenticate("Password1!")
      assert_equal result, @account
    end

    test "authenticate returns nil for incorrect password" do
      result = @account.authenticate("WrongPassword!")
      assert_nil result
    end

    test "authentication_failed! increments failed_attempts" do
      assert_difference "@account.failed_attempts" do
        @account.authentication_failed!
      end
    end

    test "authentication_success! resets failed_attempts" do
      @account.update!(failed_attempts: 5)
      @account.authentication_success!
      assert_equal @account.failed_attempts, 0
    end

    test "authenticate_by returns account for valid credentials" do
      account = Aikotoba::Account.authenticate_by(attributes: {
        email: "user@example.com",
        password: "Password1!"
      })
      assert_equal account, @account
    end

    test "authenticate_by returns nil for invalid email" do
      account = Aikotoba::Account.authenticate_by(attributes: {
        email: "nonexistent@example.com",
        password: "Password1!"
      })
      assert_nil account
    end

    test "authenticate_by returns nil for invalid password" do
      account = Aikotoba::Account.authenticate_by(attributes: {
        email: "user@example.com",
        password: "WrongPassword!"
      })
      assert_nil account
    end

    test "authenticate_by increments failed_attempts on invalid password" do
      initial_attempts = @account.failed_attempts
      Aikotoba::Account.authenticate_by(attributes: {
        email: "user@example.com",
        password: "WrongPassword!"
      })
      assert_equal @account.reload.failed_attempts, initial_attempts + 1
    end

    test "authenticate_by resets failed_attempts on successful authentication" do
      @account.update!(failed_attempts: 5)
      Aikotoba::Account.authenticate_by(attributes: {
        email: "user@example.com",
        password: "Password1!"
      })
      assert_equal @account.reload.failed_attempts, 0
    end

    test "authenticate_by locks account when max attempts exceeded" do
      Aikotoba.lockable = true
      account = Aikotoba::Account.create!(
        email: "locktest@example.com",
        password: "Password1!",
        confirmed: true,
        locked: false,
        failed_attempts: 10
      )
      Aikotoba::Account.authenticate_by(attributes: {
        email: "locktest@example.com",
        password: "WrongPassword!"
      })
      assert account.reload.locked?
      Aikotoba.lockable = false
    end

    test "authenticatable scope returns all accounts when features disabled" do
      Aikotoba.confirmable = false
      Aikotoba.lockable = false
      accounts = Aikotoba::Account.authenticatable
      assert_includes accounts.to_a, @account
    end

    test "authenticatable scope filters by target_type_name" do
      admin = Admin.create!(nickname: "admin_foo")
      admin_account = Aikotoba::Account.create!(
        email: "admin@example.com",
        password: "Password1!",
        authenticate_target: admin,
        confirmed: true
      )
      accounts = Aikotoba::Account.authenticatable(target_type_name: "Admin")
      assert_includes accounts.to_a, admin_account
      refute_includes accounts.to_a, @account
    end

    test "authenticatable scope filters confirmed accounts when confirmable" do
      Aikotoba.confirmable = true
      Aikotoba.lockable = true
      unconfirmed = Aikotoba::Account.create!(
        email: "unconfirmed@example.com",
        password: "Password1!",
        confirmed: false,
        locked: false
      )
      confirmed = Aikotoba::Account.create!(
        email: "confirmed@example.com",
        password: "Password1!",
        confirmed: true,
        locked: false
      )
      locked = Aikotoba::Account.create!(
        email: "locked@example.com",
        password: "Password1!",
        confirmed: true,
        locked: true
      )
      unlocked = Aikotoba::Account.create!(
        email: "unlocked@example.com",
        password: "Password1!",
        confirmed: true,
        locked: false
      )
      accounts = Aikotoba::Account.authenticatable
      assert_includes accounts.to_a, confirmed
      assert_includes accounts.to_a, unlocked
      assert_not_includes accounts.to_a, unconfirmed
      assert_not_includes accounts.to_a, locked
      Aikotoba.confirmable = false
      Aikotoba.lockable = false
    end
  end

  class Confirmable < ActiveSupport::TestCase
    test "confirmed scope returns only confirmed accounts" do
      confirmed = Aikotoba::Account.create!(
        email: "confirmed@example.com",
        password: "Password1!",
        confirmed: true
      )
      unconfirmed = Aikotoba::Account.create!(
        email: "unconfirmed@example.com",
        password: "Password1!",
        confirmed: false
      )
      accounts = Aikotoba::Account.confirmed
      assert_includes accounts.to_a, confirmed
      refute_includes accounts.to_a, unconfirmed
    end

    test "unconfirmed scope returns only unconfirmed accounts" do
      confirmed = Aikotoba::Account.create!(
        email: "confirmed@example.com",
        password: "Password1!",
        confirmed: true
      )
      unconfirmed = Aikotoba::Account.create!(
        email: "unconfirmed@example.com",
        password: "Password1!",
        confirmed: false
      )
      accounts = Aikotoba::Account.unconfirmed
      refute_includes accounts.to_a, confirmed
      assert_includes accounts.to_a, unconfirmed
    end

    test "confirm! updates confirmed to true" do
      account = Aikotoba::Account.create!(
        email: "user@example.com",
        password: "Password1!",
        confirmed: false
      )
      account.confirm!
      assert account.reload.confirmed?
    end
  end

  class Lockable < ActiveSupport::TestCase
    test "locked scope returns only locked accounts" do
      locked = Aikotoba::Account.create!(
        email: "locked@example.com",
        password: "Password1!",
        locked: true
      )
      unlocked = Aikotoba::Account.create!(
        email: "unlocked@example.com",
        password: "Password1!",
        locked: false
      )
      accounts = Aikotoba::Account.locked
      assert_includes accounts.to_a, locked
      refute_includes accounts.to_a, unlocked
    end

    test "unlocked scope returns only unlocked accounts" do
      locked = Aikotoba::Account.create!(
        email: "locked@example.com",
        password: "Password1!",
        locked: true
      )
      unlocked = Aikotoba::Account.create!(
        email: "unlocked@example.com",
        password: "Password1!",
        locked: false
      )
      accounts = Aikotoba::Account.unlocked
      refute_includes accounts.to_a, locked
      assert_includes accounts.to_a, unlocked
    end

    test "should_lock? returns true when failed_attempts exceeds max" do
      account = Aikotoba::Account.create!(
        email: "user@example.com",
        password: "Password1!",
        failed_attempts: 11,
        max_failed_attempts: 10
      )
      assert account.should_lock?
    end

    test "should_lock? returns false when failed_attempts does not exceed max" do
      account = Aikotoba::Account.create!(
        email: "user@example.com",
        password: "Password1!",
        failed_attempts: 10,
        max_failed_attempts: 10
      )
      refute account.should_lock?
    end

    test "lock! sets locked to true" do
      account = Aikotoba::Account.create!(
        email: "user@example.com",
        password: "Password1!",
        locked: false
      )
      account.lock!
      assert account.reload.locked?
    end

    test "unlock! sets locked to false and resets failed_attempts" do
      account = Aikotoba::Account.create!(
        email: "user@example.com",
        password: "Password1!",
        locked: true,
        failed_attempts: 10
      )
      account.unlock!
      assert_not account.reload.locked?
      assert_equal account.failed_attempts, 0
    end
  end

  class Recoverable < ActiveSupport::TestCase
    test "recover! updates password_digest" do
      account = Aikotoba::Account.create!(
        email: "user@example.com",
        password: "OldPassword1!"
      )
      old_digest = account.password_digest
      account.recover!(new_password: "NewPassword1!")
      assert_not_equal account.reload.password_digest, old_digest
      assert account.password_match?("NewPassword1!")
    end

    test "recover! validates password length" do
      account = Aikotoba::Account.create!(
        email: "user@example.com",
        password: "Password1!"
      )
      assert_raises(ActiveRecord::RecordInvalid) do
        account.recover!(new_password: "short")
      end
    end
  end

  class DefaultAttributes < ActiveSupport::TestCase
    test "confirmed defaults to false" do
      account = Aikotoba::Account.create!(
        email: "user@example.com",
        password: "Password1!"
      )
      assert account.reload.confirmed == false
    end

    test "locked defaults to false" do
      account = Aikotoba::Account.create!(
        email: "user@example.com",
        password: "Password1!"
      )
      assert account.reload.locked == false
    end

    test "failed_attempts defaults to 0" do
      account = Aikotoba::Account.create!(
        email: "user@example.com",
        password: "Password1!"
      )
      assert_equal account.reload.failed_attempts, 0
    end

    test "max_failed_attempts defaults to Aikotoba.max_failed_attempts" do
      account = Aikotoba::Account.create!(
        email: "user@example.com",
        password: "Password1!"
      )
      assert_equal account.max_failed_attempts, Aikotoba.max_failed_attempts
    end
  end
end
