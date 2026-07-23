# CHANGELOG

## Unreleased

- Move password storage off `Aikotoba::Account` entirely into a new `Aikotoba::Account::Password` model/table (`aikotoba_account_passwords`, association `account.password`), so `Account` no longer depends on password-based authentication. `Account#password`/`#password=`/`#password_digest` no longer exist — use `account.password&.value`/`account.password.value = ...`/`account.password&.digest` instead. `Account.build_by(attributes:)` still accepts a flat `:password` key (form/params contract unchanged); a new `Account.create_by!(attributes:)` mirrors `build_by`/`save!` for convenience, replacing `Account.create!(email:, password:, ...)`.

  **Breaking schema change** — this gem edits its canonical migration in place rather than shipping incremental migrations, so re-running `bin/rails aikotoba:install:migrations` will *not* pick up this change for existing installs. Add a migration by hand:

  ```ruby
  class MigratePasswordDigestToAikotobaAccountPasswords < ActiveRecord::Migration[7.0]
    def up
      create_table :aikotoba_account_passwords do |t|
        t.belongs_to :aikotoba_account, null: false, foreign_key: true, index: {unique: true, name: "index_account_passwords_on_account_id"}
        t.string :digest, null: false
        t.timestamps
      end

      execute <<~SQL
        INSERT INTO aikotoba_account_passwords (aikotoba_account_id, digest, created_at, updated_at)
        SELECT id, password_digest, created_at, updated_at FROM aikotoba_accounts
      SQL

      remove_column :aikotoba_accounts, :password_digest
    end

    def down
      add_column :aikotoba_accounts, :password_digest, :string
      execute <<~SQL
        UPDATE aikotoba_accounts
        SET password_digest = aikotoba_account_passwords.digest
        FROM aikotoba_account_passwords
        WHERE aikotoba_account_passwords.aikotoba_account_id = aikotoba_accounts.id
      SQL
      change_column_null :aikotoba_accounts, :password_digest, false
      drop_table :aikotoba_account_passwords
    end
  end
  ```

  (The `down` step's `UPDATE ... FROM` syntax is PostgreSQL; adjust for MySQL/SQLite if needed.)

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
