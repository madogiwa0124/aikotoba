# CHANGELOG

## Unreleased

- Move password storage off `Aikotoba::Account` entirely into a new `Aikotoba::Account::PasswordHash` model/table (`aikotoba_account_password_hashes`, association `account.password_hash`), so `Account` no longer depends on password-based authentication. `Account#password`/`#password=`/`#password_digest` no longer exist, and `account.password_hash` exposes no plaintext reader either — only `account.password_hash&.digest` (the stored hash) is public; there is no `#value`/`#plaintext` getter, only `#generate(input)` to (re)compute it. `Account.build_by(attributes:)` still accepts a flat `:password` key (form/params contract unchanged); a new `Account.create_by!(attributes:)` mirrors `build_by`/`save!` for convenience, replacing `Account.create!(email:, password:, ...)`.
- `Aikotoba::Test::AuthenticationHelper#aikotoba_sign_in` (both `Request` and `System` variants) now requires an explicit `password:` keyword argument — `aikotoba_sign_in(account)` no longer works. This closes a latent bug: the old signature read `account.password.value` internally, which is a transient in-memory attribute that's `nil` for any account fetched fresh from the database (e.g. via `Account.find`), so signing in with a reloaded account silently posted a blank password and failed. Update call sites to `aikotoba_sign_in(account, password: "the-plaintext-password")`.
- Fixed a timing side-channel in `Account::PasswordHash.authenticate_by`: authenticating against an account that exists but has no password (e.g. a future magic-link-only account) used to return instantly, skipping the Argon2 computation entirely — making "account has no password" distinguishable from "wrong password"/"account not found" by response time. It now pays the same dummy-hash cost as the existing not-found path. Separately, a blank password used to skip hashing too (regardless of account state); `authenticate_by` now returns `nil` for a blank password before looking up the account at all, since the caller already knows their own input was blank and a uniform instant response leaks nothing.
- Removed `PasswordHash`'s separate `validates :digest, presence: true`: it was entirely redundant with `validates :plaintext, presence: true` (the only way `digest` ends up blank is `generate` being given a blank input, which always fails the `plaintext` check at the same time), and its presence caused `register!`/`Account::Recovery#recover!` to leak a raw internal attribute name ("Password hash digest can't be blank") and render "Password can't be blank" twice for a blank password. The DB's `null: false` constraint still guards `digest` independently.
- Fixed `PasswordHash#plaintext`'s presence/length validation silently not running for an *existing* account: it was scoped `on: [:create, :recover]`, but a has_one autosave association validates an already-persisted nested record under its own natural `:update` context unless the parent save is given a custom context — so `account.password_hash.generate("short"); account.save` (as opposed to `#recover!`, which explicitly passes `context: :recover`) skipped the check entirely and silently persisted an invalid password. The validation is now unconditional; this only costs anything when `password_hash` actually has pending changes to save (i.e. `generate` was called), so it doesn't affect saving an account for unrelated reasons.
- Added `Account#update_by(attributes:)`/`#update_by!(attributes:)`, the update-side counterpart to `.build_by`/`.create_by!`: like those, they accept a flat `:password` key and translate it into the `password_hash` association (building it if the account didn't have one yet), so updating an account's email and password together in one validated save doesn't require knowing `password_hash`/`#generate` at all. `account.update!(password: ...)` still doesn't work, the same way `Account.new(password: ...)` doesn't — `Account` has no `password=` for mass-assignment to land on.

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
