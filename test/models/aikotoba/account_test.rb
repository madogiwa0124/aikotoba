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

  class OptionalHasOne < ActiveSupport::TestCase
    # NOTE: Anything other than :destroy would have to be forwarded to has_one to work,
    #       which would register the unconditional destroy callback optional_has_one
    #       exists to avoid. Raising beats silently doing nothing.
    test "optional_has_one rejects dependent options it cannot honour" do
      error = assert_raises(ArgumentError) do
        Class.new(Aikotoba::Account) do
          optional_has_one :nullified_token, dependent: :nullify
        end
      end
      assert_match(/dependent: :destroy only/, error.message)
    end

    test "optional_has_one keeps the replace-on-rebuild cleanup dependent: :destroy provides" do
      # NOTE: The reflection option is set after has_one so no unconditional callback is
      #       registered, but HasOneAssociation#remove_target! still reads it at runtime.
      #       Without it, the second build_ + save! below raises RecordNotSaved.
      assert_equal :destroy, Aikotoba::Account.reflect_on_association(:confirmation_token).options[:dependent]

      account = Aikotoba::Account.create_by!(attributes: {
        email: "user@example.com",
        password: "Password1!"
      })
      Aikotoba::Account::Confirmation.create_token!(account: account, notify: false)
      first_token_id = account.confirmation_token.id

      Aikotoba::Account::Confirmation.create_token!(account: account, notify: false)

      assert_equal 1, Aikotoba::Account::ConfirmationToken.where(aikotoba_account_id: account.id).count
      assert_not Aikotoba::Account::ConfirmationToken.exists?(first_token_id)
    end
  end

  # NOTE: Optional-feature token tables are cleaned up by hand-written before_destroy
  #       callbacks instead of dependent: :destroy, so that a host app which never
  #       migrated a feature's table can still destroy accounts (see
  #       OptionalAssociation). These guard both halves of that trade: the
  #       cleanup still happens when the table is there, and nothing queries the table
  #       when it isn't.
  class DestroyingOptionalTokens < ActiveSupport::TestCase
    OPTIONAL_TOKEN_TABLES = %w[
      aikotoba_account_confirmation_tokens
      aikotoba_account_unlock_tokens
      aikotoba_account_recovery_tokens
      aikotoba_account_magic_link_tokens
      aikotoba_account_refresh_tokens
    ].freeze

    def setup
      @account = Aikotoba::Account.create_by!(attributes: {
        email: "user@example.com",
        password: "Password1!"
      })
    end

    def build_every_optional_token!
      Aikotoba::Account::Confirmation.create_token!(account: @account, notify: false)
      Aikotoba::Account::Lock.create_unlock_token!(account: @account, notify: false)
      Aikotoba::Account::Recovery.create_token!(account: @account, notify: false)
      Aikotoba::Account::MagicLink.create_token!(account: @account, notify: false)
      Aikotoba::Account::Session.start!(account: @account, origin: :api)
    end

    def sql_statements_while
      statements = []
      subscriber = ->(*, payload) { statements << payload[:sql] }
      ActiveSupport::Notifications.subscribed(subscriber, "sql.active_record") { yield }
      statements
    end

    test "destroy! removes every optional token" do
      build_every_optional_token!
      assert_difference [
        "Aikotoba::Account::ConfirmationToken.count",
        "Aikotoba::Account::UnlockToken.count",
        "Aikotoba::Account::RecoveryToken.count",
        "Aikotoba::Account::MagicLinkToken.count",
        "Aikotoba::Account::RefreshToken.count",
        "Aikotoba::Account::Session.count"
      ], -1 do
        Aikotoba::Account.find(@account.id).destroy!
      end
    end

    test "destroy! removes optional tokens even after their feature flag is turned off" do
      # NOTE: The reverse of the test below. Gating the callbacks on the feature flag
      #       would strand these rows and raise ActiveRecord::InvalidForeignKey here.
      build_every_optional_token!
      with_aikotoba_features_disabled do
        assert_nothing_raised { Aikotoba::Account.find(@account.id).destroy! }
      end
      assert_equal 0, Aikotoba::Account::ConfirmationToken.where(aikotoba_account_id: @account.id).count
      assert_equal 0, Aikotoba::Account::MagicLinkToken.where(aikotoba_account_id: @account.id).count
    end

    test "destroy! never queries an optional token table that does not exist" do
      # NOTE: The actual bug this whole arrangement exists for -- a host app with a
      #       feature disabled and its migration never run used to hit PG::UndefinedTable
      #       on every Account#destroy!.
      session = Aikotoba::Account::Session.start!(account: @account, origin: :browser)
      with_optional_token_tables_dropped do
        statements = sql_statements_while do
          session.revoke!
          Aikotoba::Account.find(@account.id).destroy!
        end
        assert_empty statements.grep(/#{Regexp.union(OPTIONAL_TOKEN_TABLES)}/).grep_v(/pragma_table_list|information_schema|sqlite_master/)
      end
    end

    private

    def with_aikotoba_features_disabled
      previous = {
        confirmable: Aikotoba.confirmable,
        lockable: Aikotoba.lockable,
        recoverable: Aikotoba.recoverable,
        magic_link_authenticatable: Aikotoba.magic_link_authenticatable,
        api_authenticatable: Aikotoba.api_authenticatable
      }
      previous.each_key { |feature| Aikotoba.public_send(:"#{feature}=", false) }
      yield
    ensure
      previous.each { |feature, value| Aikotoba.public_send(:"#{feature}=", value) }
    end

    # NOTE: SQLite (the test adapter) has transactional DDL, so the drops roll back with
    #       the surrounding transaction. The schema cache has to be cleared on both sides
    #       because OptionalAssociation caches negative lookups too.
    def with_optional_token_tables_dropped
      connection = ActiveRecord::Base.connection
      ActiveRecord::Base.transaction do
        OPTIONAL_TOKEN_TABLES.each { |table| connection.drop_table(table) }
        Aikotoba::Account.connection_pool.schema_cache.clear!
        yield
        raise ActiveRecord::Rollback
      end
    ensure
      Aikotoba::Account.connection_pool.schema_cache.clear!
    end
  end
end
