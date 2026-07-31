# frozen_string_literal: true

require "test_helper"

class Aikotoba::AccountTest < ActiveSupport::TestCase
  class Registrable < ActiveSupport::TestCase
    test "build_by creates account with email and password" do
      account = Aikotoba::Account.build_by(attributes: {
        email: "user@example.com",
        password: "Password1!"
      })
      assert account.email == "user@example.com"
      assert account.password_hash.digest.present?
    end

    test "build_by passes authenticate_target through new(attrs) so after_initialize sees it" do
      # NOTE: regression guard for a real footgun found while refactoring this: build_by
      #       must construct via `new(attrs)` in one shot, not `new.tap { assign_attributes
      #       (attrs) }`, because Account's after_initialize (which defines the dynamic
      #       `account.admin`-style accessor from authenticate_target) already runs by the
      #       time a bare `new` returns -- an authenticate_target assigned afterward is too
      #       late for it to see, silently losing the accessor.
      admin = Admin.create!(nickname: "admin_foo")
      account = Aikotoba::Account.build_by(attributes: {
        email: "admin@example.com",
        authenticate_target: admin
      })
      assert account.respond_to?(:admin)
      assert_equal admin, account.admin
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

    test "register! surfaces password length errors under :password" do
      account = Aikotoba::Account.build_by(attributes: {
        email: "user@example.com",
        password: "short"
      })
      assert_raises(ActiveRecord::RecordInvalid) { account.register! }
      assert_includes account.errors.full_messages, "Password is too short (minimum is 8 characters)"
    end

    test "build_by and register! do not require any credential, by design" do
      # NOTE: Account itself must not know or care which auth method(s) an
      #       account ends up with, so the generic model API stays permissive.
      #       Requiring a credential is the job of a specific registration
      #       flow (e.g. AccountsController for password) — see the "Auth
      #       method ownership principle" in copilot-instructions.md.
      account = Aikotoba::Account.build_by(attributes: {email: "user@example.com"})
      assert_nil account.password_hash
      assert_difference "Aikotoba::Account.count", 1 do
        account.register!
      end
      assert account.persisted?
      assert_nil account.password_hash
    end

    test "build_by still validates password when the key is explicitly nil, unlike an omitted key" do
      # NOTE: an omitted :password key is the intentional passwordless path above, but an
      #       explicit password: nil (e.g. a JSON API client sending "password": null) must
      #       not be silently treated the same way — it should surface a validation error.
      account = Aikotoba::Account.build_by(attributes: {email: "user@example.com", password: nil})
      assert_not_nil account.password_hash
      assert_raises(ActiveRecord::RecordInvalid) { account.register! }
      assert_includes account.errors.full_messages, "Password can't be blank"
    end

    test "register! surfaces a blank password as exactly one clean message" do
      # NOTE: regression guard for a real bug hit while building this: PasswordHash used to
      #       also validate :digest presence independently of :plaintext, so a blank
      #       password failed both validations at once, leaking a raw internal attribute
      #       name ("Password hash digest can't be blank") into full_messages.
      account = Aikotoba::Account.build_by(attributes: {email: "user@example.com", password: ""})
      assert_raises(ActiveRecord::RecordInvalid) { account.register! }
      messages = account.errors.full_messages
      assert_equal ["Password can't be blank", "Password is too short (minimum is 8 characters)"], messages
    end

    test "update_by! updates other attributes and the password together in one save" do
      account = Aikotoba::Account.create_by!(attributes: {email: "user@example.com", password: "Password1!"})
      old_digest = account.password_hash.digest

      account.update_by!(attributes: {email: "changed@example.com", password: "NewPassword1!"})

      assert_equal "changed@example.com", account.reload.email
      refute_equal old_digest, account.password_hash.digest
      assert account.password_hash.match?("NewPassword1!")
    end

    test "update_by! validates the new password, rolling back with the rest of the save" do
      account = Aikotoba::Account.create_by!(attributes: {email: "user@example.com", password: "Password1!"})

      assert_raises(ActiveRecord::RecordInvalid) do
        account.update_by!(attributes: {email: "changed@example.com", password: "short"})
      end
      assert_includes account.errors.full_messages, "Password is too short (minimum is 8 characters)"
      account.reload
      assert_equal "user@example.com", account.email
      assert account.password_hash.match?("Password1!")
    end

    test "update_by! without a :password key leaves an existing password_hash untouched" do
      account = Aikotoba::Account.create_by!(attributes: {email: "user@example.com", password: "Password1!"})
      old_digest = account.password_hash.digest

      account.update_by!(attributes: {email: "changed@example.com"})

      assert_equal old_digest, account.reload.password_hash.digest
    end

    test "update_by! builds a password_hash for a previously passwordless account" do
      account = Aikotoba::Account.create_by!(attributes: {email: "user@example.com"})
      assert_nil account.password_hash

      account.update_by!(attributes: {password: "Password1!"})

      assert account.reload.password_hash.match?("Password1!")
    end
  end

  class Authenticatable < ActiveSupport::TestCase
    def setup
      @account = Aikotoba::Account.create_by!(attributes: {
        email: "user@example.com",
        password: "Password1!",
        confirmed: true,
        locked: false,
        failed_attempts: 0
      })
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

    test "authenticatable scope returns all accounts when features disabled" do
      Aikotoba.confirmable = false
      Aikotoba.lockable = false
      accounts = Aikotoba::Account.authenticatable
      assert_includes accounts.to_a, @account
    end

    test "authenticatable scope filters by target_type_name" do
      admin = Admin.create!(nickname: "admin_foo")
      admin_account = Aikotoba::Account.create_by!(attributes: {
        email: "admin@example.com",
        password: "Password1!",
        authenticate_target: admin,
        confirmed: true
      })
      accounts = Aikotoba::Account.authenticatable(target_type_name: "Admin")
      assert_includes accounts.to_a, admin_account
      refute_includes accounts.to_a, @account
    end

    test "authenticatable scope filters confirmed accounts when confirmable" do
      Aikotoba.confirmable = true
      Aikotoba.lockable = true
      unconfirmed = Aikotoba::Account.create_by!(attributes: {
        email: "unconfirmed@example.com",
        password: "Password1!",
        confirmed: false,
        locked: false
      })
      confirmed = Aikotoba::Account.create_by!(attributes: {
        email: "confirmed@example.com",
        password: "Password1!",
        confirmed: true,
        locked: false
      })
      locked = Aikotoba::Account.create_by!(attributes: {
        email: "locked@example.com",
        password: "Password1!",
        confirmed: true,
        locked: true
      })
      unlocked = Aikotoba::Account.create_by!(attributes: {
        email: "unlocked@example.com",
        password: "Password1!",
        confirmed: true,
        locked: false
      })
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
      confirmed = Aikotoba::Account.create_by!(attributes: {
        email: "confirmed@example.com",
        password: "Password1!",
        confirmed: true
      })
      unconfirmed = Aikotoba::Account.create_by!(attributes: {
        email: "unconfirmed@example.com",
        password: "Password1!",
        confirmed: false
      })
      accounts = Aikotoba::Account.confirmed
      assert_includes accounts.to_a, confirmed
      refute_includes accounts.to_a, unconfirmed
    end

    test "unconfirmed scope returns only unconfirmed accounts" do
      confirmed = Aikotoba::Account.create_by!(attributes: {
        email: "confirmed@example.com",
        password: "Password1!",
        confirmed: true
      })
      unconfirmed = Aikotoba::Account.create_by!(attributes: {
        email: "unconfirmed@example.com",
        password: "Password1!",
        confirmed: false
      })
      accounts = Aikotoba::Account.unconfirmed
      refute_includes accounts.to_a, confirmed
      assert_includes accounts.to_a, unconfirmed
    end

    test "confirm! updates confirmed to true" do
      account = Aikotoba::Account.create_by!(attributes: {
        email: "user@example.com",
        password: "Password1!",
        confirmed: false
      })
      account.confirm!
      assert account.reload.confirmed?
    end
  end

  class Lockable < ActiveSupport::TestCase
    test "locked scope returns only locked accounts" do
      locked = Aikotoba::Account.create_by!(attributes: {
        email: "locked@example.com",
        password: "Password1!",
        locked: true
      })
      unlocked = Aikotoba::Account.create_by!(attributes: {
        email: "unlocked@example.com",
        password: "Password1!",
        locked: false
      })
      accounts = Aikotoba::Account.locked
      assert_includes accounts.to_a, locked
      refute_includes accounts.to_a, unlocked
    end

    test "unlocked scope returns only unlocked accounts" do
      locked = Aikotoba::Account.create_by!(attributes: {
        email: "locked@example.com",
        password: "Password1!",
        locked: true
      })
      unlocked = Aikotoba::Account.create_by!(attributes: {
        email: "unlocked@example.com",
        password: "Password1!",
        locked: false
      })
      accounts = Aikotoba::Account.unlocked
      refute_includes accounts.to_a, locked
      assert_includes accounts.to_a, unlocked
    end

    test "should_lock? returns true when failed_attempts exceeds max" do
      account = Aikotoba::Account.create_by!(attributes: {
        email: "user@example.com",
        password: "Password1!",
        failed_attempts: 11,
        max_failed_attempts: 10
      })
      assert account.should_lock?
    end

    test "should_lock? returns false when failed_attempts does not exceed max" do
      account = Aikotoba::Account.create_by!(attributes: {
        email: "user@example.com",
        password: "Password1!",
        failed_attempts: 10,
        max_failed_attempts: 10
      })
      refute account.should_lock?
    end

    test "lock! sets locked to true" do
      account = Aikotoba::Account.create_by!(attributes: {
        email: "user@example.com",
        password: "Password1!",
        locked: false
      })
      account.lock!
      assert account.reload.locked?
    end

    test "unlock! sets locked to false and resets failed_attempts" do
      account = Aikotoba::Account.create_by!(attributes: {
        email: "user@example.com",
        password: "Password1!",
        locked: true,
        failed_attempts: 10
      })
      account.unlock!
      assert_not account.reload.locked?
      assert_equal account.failed_attempts, 0
    end
  end

  class DefaultAttributes < ActiveSupport::TestCase
    test "confirmed defaults to false" do
      account = Aikotoba::Account.create_by!(attributes: {
        email: "user@example.com",
        password: "Password1!"
      })
      assert account.reload.confirmed == false
    end

    test "locked defaults to false" do
      account = Aikotoba::Account.create_by!(attributes: {
        email: "user@example.com",
        password: "Password1!"
      })
      assert account.reload.locked == false
    end

    test "failed_attempts defaults to 0" do
      account = Aikotoba::Account.create_by!(attributes: {
        email: "user@example.com",
        password: "Password1!"
      })
      assert_equal account.reload.failed_attempts, 0
    end

    test "max_failed_attempts defaults to Aikotoba.max_failed_attempts" do
      account = Aikotoba::Account.create_by!(attributes: {
        email: "user@example.com",
        password: "Password1!"
      })
      assert_equal account.max_failed_attempts, Aikotoba.max_failed_attempts
    end
  end
end
