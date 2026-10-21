# CHANGELOG

## Unreleased

- **Breaking**: Two scopes can no longer share an `authenticate_for` value. `add_scope`, and app boot (after your initializers), raise `Aikotoba::Errors::InvalidScopeConfiguration` instead. The scope an account's emails link to is picked by its target type, so a shared value made that choice ambiguous. Note that `add_scope` copies `authenticate_for` from the default scope unless you pass it. If your default scope sets one, pass `authenticate_for:` (or `nil`) to each added scope.

- **Breaking**: A scope's confirm, unlock, password reset and magic link endpoints now only handle accounts that can sign in to that scope. With `authenticate_for` set, they send emails only to accounts with that `authenticate_target_type` and return 404 for tokens belonging to other accounts. Before, for example, `/admin/recover` would send a reset email to any account. The emails now link to the account's own scope (the first scope whose `authenticate_for` matches, else the default scope) instead of always to the default scope. Links in emails sent before upgrading still point to the default scope's paths. Those keep working when the default scope has no `authenticate_for`, and otherwise the user can request a new email.

- **Breaking**: A scope with `authenticate_for` no longer gets a sign up route (`sign_up_path`) or a sign up link on its sign in page, even when `Aikotoba.registerable` is enabled. Before, `Aikotoba.registerable` was global, so every scope exposed a public sign up form. The README's `after_create_account_process` example then created an `Admin` for any sign up under `aikotoba_scope.admin?`, which let anyone create an Admin account. Without that hook, the form created accounts with no target that could never sign in to that scope. Create those accounts yourself instead (see the README), and remove any `aikotoba_scope.admin?`-style branch that builds a restricted target from your `after_create_account_process`.

- **Breaking**: Require Rails 7.2 or later (was `>= 6.1.4`). Token emails now wait for `ActiveRecord.after_all_transactions_commit`, which was added in Rails 7.2.

- **Breaking**: Confirmation, unlock, password recovery and magic link emails are now sent with `deliver_later` instead of `deliver_now`, and only after every open transaction commits. Previously they were sent inside the transaction that created the token, so a rollback (e.g. an exception in `after_create_account_process`) could leave the user holding a link to a token that no longer exists, and an SMTP outage turned the request into a 500. Configure a persistent Active Job backend in production; the default `:async` adapter loses queued emails on restart. In tests, wrap the step that sends the email in `assert_emails` (or `perform_enqueued_jobs`) before reading `ActionMailer::Base.deliveries`.

- **Breaking**: Remove `Aikotoba.keep_legacy_login_session` and the migration path that turned a pre-v0.2.0 `session[session_key]` (account id) into a cookie + DB session. It was a v0.2.0 upgrade aid. Delete any `Aikotoba.keep_legacy_login_session = ...` line from your initializer, since it now raises `NoMethodError`. Apps upgrading straight from v0.1.x will see sessions created by v0.1.x signed out once.

- **Breaking**: Remove the deprecated top-level scope accessors (`Aikotoba.sign_in_path`, `Aikotoba.sign_in_path=`, and the same pair for every other `default_scope` key) along with `Aikotoba::DEPRECATOR`. They have warned since v0.2.0. Replace `Aikotoba.sign_in_path = "/login"` with `Aikotoba.default_scope[:sign_in_path] = "/login"` (or `Aikotoba.default_scope = {sign_in_path: "/login"}`), and `Aikotoba.sign_in_path` with `Aikotoba.default_scope[:sign_in_path]`. Leftover calls now raise `NoMethodError`.

- Move password storage off `Aikotoba::Account` entirely into a new `Aikotoba::Account::PasswordHash` model/table (`aikotoba_account_password_hashes`, association `account.password_hash`), so `Account` no longer depends on password-based authentication. `Account#password`/`#password=`/`#password_digest`/`#authenticate`/`#authenticate_by`/`#recover!` no longer exist; `account.password_hash` exposes no plaintext reader either — only `account.password_hash&.digest` (the stored hash) is public, and there is no `#value`/`#plaintext` getter, only `#generate(input)` to (re)compute it.

  **Breaking schema change** — this gem edits its canonical migration in place rather than shipping incremental migrations, so re-running `bin/rails aikotoba:install:migrations` will *not* pick up this change for existing installs. Add a migration by hand:

  ```ruby
  class MigratePasswordDigestToAikotobaAccountPasswordHashes < ActiveRecord::Migration[7.0]
    def up
      create_table :aikotoba_account_password_hashes do |t|
        t.belongs_to :aikotoba_account, null: false, foreign_key: true, index: {unique: true, name: "index_account_password_hashes_on_account_id"}
        t.string :digest, null: false
        t.timestamps
      end

      execute <<~SQL
        INSERT INTO aikotoba_account_password_hashes (aikotoba_account_id, digest, created_at, updated_at)
        SELECT id, password_digest, created_at, updated_at FROM aikotoba_accounts
      SQL

      remove_column :aikotoba_accounts, :password_digest
    end

    def down
      add_column :aikotoba_accounts, :password_digest, :string
      execute <<~SQL
        UPDATE aikotoba_accounts
        SET password_digest = aikotoba_account_password_hashes.digest
        FROM aikotoba_account_password_hashes
        WHERE aikotoba_account_password_hashes.aikotoba_account_id = aikotoba_accounts.id
      SQL
      change_column_null :aikotoba_accounts, :password_digest, false
      drop_table :aikotoba_account_password_hashes
    end
  end
  ```

  (The `down` step's `UPDATE ... FROM` syntax is PostgreSQL; adjust for MySQL/SQLite if needed.)

  The `down` step's `change_column_null` will fail if any account was created without a
  password (e.g. via `Account.build_by(attributes: {email:})`, which this release
  intentionally allows at the model layer). If you may have such accounts, back them out
  or give them a password before rolling back.

- `Account.build_by(attributes:)`/`.create_by!(attributes:)` (create) and the new `#update_by(attributes:)`/`#update_by!(attributes:)` (update) all accept a flat `:password` key and translate it into the `password_hash` association, so the `account[password]` form/params contract is unchanged and neither creating nor updating an account's password requires knowing `password_hash`/`#generate` directly. `account.update!(password: ...)`/`Account.create!(email:, password:, ...)` don't work — `Account` has no `password=` for mass-assignment to land on.
- `Account::PasswordHash.authenticate_by` is constant-time with respect to account/password state for any non-blank password: an account that doesn't exist and an account that exists but has no password both cost the same as a real failed-password attempt, so neither is distinguishable from the other by response time. A blank password is handled separately and returns instantly without hashing — safe, since the caller already knows their own input was blank, so its speed reveals nothing about the account.
- `Aikotoba::Test::AuthenticationHelper#aikotoba_sign_in` (both `Request` and `System` variants) now requires an explicit `password:` keyword argument instead of reading it off the account — `aikotoba_sign_in(account, password: "the-plaintext-password")`.
- Add (experimental) `MagicLinkAuthenticatable`: sign in via a one-time link sent by email, no password required. Set `Aikotoba.magic_link_authenticatable = true` to enable. Works for accounts with no password at all, since password storage is entirely owned by `Aikotoba::Account::PasswordHash`.
- Optional features' tables now ship **commented out** in the canonical migration instead of being created unconditionally. All five (Confirmable, Lockable, Recoverable, MagicLinkAuthenticatable, API Token Authenticatable) default to off, so a fresh `bin/rails aikotoba:install:migrations` + `db:migrate` creates only the always-required tables (accounts / password hashes / sessions); uncomment the block for each feature you actually enable. Enabling a feature after that migration has run means adding the same `create_table` in a migration of your own. See the README's [Getting Start](README.md#getting-start) section. (Existing installs are unaffected: this is still a single, edited-in-place migration, so nothing new is copied and nothing is dropped from a database that already has these tables.)

- `Account#destroy!`/`Account::Session#destroy!` (and `#revoke!`) no longer unconditionally query each optional feature's token table. Each optional `has_one` (`confirmation_token`, `unlock_token`, `recovery_token`, `magic_link_token`, `refresh_token`) is now cleaned up via a `before_destroy` callback instead of an unconditional `dependent: :destroy`. `Account`'s callbacks skip a token table that doesn't exist (a schema-cache lookup, so no per-destroy query cost), and `Account::Session` only looks for a refresh token on an `origin: :api` session. Combined with the migration split above, this makes it safe for an unused feature's table to not exist at all, while still cleaning up leftover token rows if you enable a feature, use it, and later turn its flag back off. (Turning a flag on without migrating its table remains unsupported and will still raise a real database error the first time that feature's code path runs — see the README.)
- Add opt-in redirect back to the originally requested page after sign in: replace the `redirect_to` in your `authenticate_account!` with `aikotoba_request_authentication` (provided by `Aikotoba::Authenticatable`, modeled on the Rails authentication generator's `request_authentication`), and a successful sign in (password or [MagicLinkAuthenticatable](README.md#experimental-magiclinkauthenticatable)) redirects back to that `request.fullpath` instead of `after_sign_in_path`. Only a non-XHR HTML `GET` with a non-protocol-relative path is stored, per scope, and it's consumed at most once. See the README's [Authenticatable](README.md#authenticatable) section.

## :gift: 2026/02/25 `v0.2.0` released.

- Add multi-scope support
  - https://github.com/madogiwa0124/aikotoba/commit/c9f953f
- Migrate session management to signed cookies + DB-backed sessions
  - https://github.com/madogiwa0124/aikotoba/commit/21d0df4
- Add rate limiting for email-sending endpoints (Rails 8+ only)
  - https://github.com/madogiwa0124/aikotoba/commit/460ad29
- Set the autocomplete attribute to improve accessibility.
  - https://github.com/madogiwa0124/aikotoba/commit/0ae56da81f86070f9875c747cdd76314274b3f7e

## :gift: 2022/05/29 `v0.1.1` released.

- Dependent classes and values can be injected with initialize.
  - https://github.com/madogiwa0124/aikotoba/commit/630f031a5b20262f758273c38a4a28702eb6b344
- The flg for prevent timing attack can be passed as an argument.
  - https://github.com/madogiwa0124/aikotoba/commit/50da94229d825604fa06fab9d9d747966bc63258
- Removed namespace `Value`.
  - https://github.com/madogiwa0124/aikotoba/commit/1be0f3942d9dcb8267f18f36f2020c42c1ed7d48

## :gift: 2022/03/11 `v0.1.0` released.

- :tada: first release
