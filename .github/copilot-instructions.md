# Copilot Instructions for Aikotoba

This repository is a Rails Engine gem that provides simple email/password authentication. Use these notes to be productive quickly when navigating, extending, and testing the engine.

## Big Picture

- Engine: Isolated via `Aikotoba::Engine` in [lib/aikotoba/engine.rb](../lib/aikotoba/engine.rb). All routes/controllers/models live under the `Aikotoba` namespace.
- Core flows: Sign in/out live in [app/controllers/aikotoba/sessions_controller.rb](../app/controllers/aikotoba/sessions_controller.rb); registration, confirmation, lock/unlock, and recovery are implemented as separate controllers and models under `app/controllers/aikotoba/*` and `app/models/aikotoba/account/*`.
- Session model: Login sessions are persisted in [app/models/aikotoba/account/session.rb](../app/models/aikotoba/account/session.rb) and paired with a signed cookie managed by the controller concern [app/controllers/concerns/aikotoba/authenticatable.rb](../app/controllers/concerns/aikotoba/authenticatable.rb).
- Configuration and scopes: Global settings and dynamic “scope” routing are defined in [lib/aikotoba.rb](../lib/aikotoba.rb). Scopes control paths and behavior (e.g., `sign_in_path`, `session_key`, `authenticate_for`).

## Routing and Scopes

- Routes are generated per scope in [config/routes.rb](../config/routes.rb), enabling or disabling feature groups via constraints in [lib/aikotoba/constraints](../lib/aikotoba/constraints).
- Scopes are merged from `default` and can be extended via `Aikotoba.add_scope(:admin, {...})`. Paths are dynamically determined by the current root path. See examples in the README.
- Helper: Controllers include `Aikotoba::Scopable` to fetch the current scope config and expose `aikotoba_scoped_path`.

## Authentication Pattern

- Include concern: Apps include `Aikotoba::Authenticatable` (often in `ApplicationController`) to get `aikotoba_current_account`, `aikotoba_sign_in`, and `aikotoba_sign_out`. See [app/controllers/concerns/aikotoba/authenticatable.rb](../app/controllers/concerns/aikotoba/authenticatable.rb).
- DB + Cookie session: On sign-in, a new `Aikotoba::Account::Session` record is created and a signed cookie with the token is set. On sign-out, the record is revoked and the cookie cleared.
- Target type filtering: If a scope sets `authenticate_for`, authentication and session lookup filter by `authenticate_target_type`.

## Models and Features

- Account: Generic identity and session/lock bookkeeping in [app/models/aikotoba/account.rb](../app/models/aikotoba/account.rb) — `authenticate_target` ("authenticate_for"), sessions, the `authenticatable` scope, `failed_attempts`/`locked` counters. It does not know how credentials are checked.
- Tokens: Confirmation/Unlock/Recovery tokens under [app/models/aikotoba/account/\*](../app/models/aikotoba/account) use `Account::Token` ([app/models/aikotoba/account/token.rb](../app/models/aikotoba/account/token.rb)).
- Token encryption: Optional deterministic encryption for `token` fields via `Aikotoba.encrypted_token`. See concern in [app/models/concerns/aikotoba/token_encryptable.rb](../app/models/concerns/aikotoba/token_encryptable.rb) and note AR 7+ requirement.

### Auth method ownership principle

`Account` must not depend on the concrete implementation of any authentication
method. Each method owns a class that holds its own credential storage,
matching logic, and authentication entry point — `Account` only holds what's
generic across methods (identity, sessions, `authenticate_target`,
brute-force lock counters). Password is the first (and currently only)
example of this:

- Storage + matching: [app/models/aikotoba/account/password_hash.rb](../app/models/aikotoba/account/password_hash.rb) — `Aikotoba::Account::PasswordHash` (table `aikotoba_account_password_hashes`) owns the password digest and `#match?`. `Account` itself has no password-shaped methods at all, only a `has_one :password_hash` association (`account.password_hash&.digest`). There is no public plaintext reader — `#generate(input)` computes and stores the digest, but the plaintext it was given is kept in a private `plaintext` reader, only used internally by the presence/length validation. `Registrable#build_by`/`.create_by!` (create-side) and `#update_by`/`#update_by!` (update-side counterpart, since `account.update!(password:)` can't work any more than `Account.new(password:)` can) are the only places that still know the `:password` key exists, translating it into `(build_)password_hash.generate(password)` so the flat `account[password]` form/params contract stays unchanged. Association/attribute naming deliberately avoids the bare word `password` — Rails' `has_secure_password` convention makes `.password` almost universally mean "returns a plaintext string", and a `has_one :password` here previously caused a real bug (a test helper read `account.password.value`, silently broken for any reloaded account, since that plaintext is never persisted).
- Auth entry point: `Aikotoba::Account::PasswordHash.authenticate_by(attributes:, target_type_name:)` — not `Account.authenticate_by`. It finds the candidate account via the generic `Account.find_by_identifier`, then owns the credential check and the failed/success bookkeeping, triggering `Account::Lock` when appropriate. It also pays a constant Argon2 cost even when the found account has no `password_hash`, so "account exists but has no password" isn't distinguishable from "wrong password"/"account not found" by response time.
- Recovery: `Account::PasswordHash#recover!` (not `Account#recover!`) owns resetting the credential. `Account::Recovery` ([app/models/aikotoba/account/recovery.rb](../app/models/aikotoba/account/recovery.rb)) still owns the generic token lifecycle (issue/notify/destroy). `register!`'s `save!` failing on a nested `password_hash` validation needs **no error-remapping code at all** — Rails wraps has_one/belongs_to autosave validation failures in `ActiveModel::NestedError`, whose `#message` delegates straight to the *original* error's own base (`password_hash`, which does respond to its own attributes), so `account.errors.full_messages` never raises even though `Account` has no real `password_hash.plaintext`-shaped method. Only the *display label* needed help, via `config/locales/en.yml`'s nested `activerecord.attributes.aikotoba/account/password_hash.plaintext`. The one place a real remap is still required is `Account::Recovery#recover!`'s "account has no password_hash" guard clause, which calls `errors.add(:password_hash, :blank)` directly — `.add` (unlike `.import`/autosave) builds a plain, non-delegating `Error` against `Account` itself, so it genuinely needs a real attribute Account responds to (the `has_one` reader, not the removed `:password`).

When adding a new auth method, mirror this shape (own class, own
`authenticate_by`, own storage/recovery) rather than adding another
method-specific branch to `Account`. Generic mechanisms that any
credential-guessing method could reuse (e.g. the `Lockable` lock/unlock
counters and scopes) stay on `Account`; only the *decision* to trigger them
lives in the method's own `authenticate_by`.

`Account.build_by`/`register!` intentionally do not require any credential
to be present — `build_by` only builds a `password` association when a
`:password` key is actually passed in, and `register!` happily saves an
account with no credential at all. This is by design, not a gap: a future
passwordless method (magic link, passkey) needs to be able to register an
account through the exact same generic entry point without a password ever
existing. Enforcing "this account must have a usable credential" is the
job of the specific registration flow, not the generic model layer — e.g.
`AccountsController#build_account` (the password sign-up form) defaults
`:password` to `""` before calling `build_by` specifically so
`Account::PasswordHash`'s own presence validation rejects an omitted password.
A different auth method's registration controller would enforce its own
credential's presence the same way, on its own terms.

### Optional-feature schema: per-feature migrations and destroy-safety

Confirmable/Lockable/Recoverable/MagicLinkAuthenticatable/API Token Authenticatable
each own one table (`aikotoba_account_confirmation_tokens` /
`_unlock_tokens` / `_recovery_tokens` / `_magic_link_tokens` /
`_refresh_tokens`). Two related but separate conventions apply to them:

**Migration layout**: everything stays in the single canonical
[db/migrate/20211204121532_create_aikotoba_accounts.rb](../db/migrate/20211204121532_create_aikotoba_accounts.rb),
edited in place per the [Developer Workflows](#developer-workflows) section
below. The always-required tables (`aikotoba_accounts`,
`aikotoba_account_password_hashes`, `aikotoba_account_sessions`) are live;
each optional feature's `create_table` sits **commented out** below them,
since every one of those features defaults to off. A host app uncomments the
blocks it wants before `db:migrate`, or adds an equivalent migration of its
own if it enables a feature later. When adding a new optional feature, add
its table to that file commented out too — don't create a separate migration
file, and don't leave it enabled by default.

The dummy app can't uncomment a file it doesn't own, and its tests exercise
every feature, so it creates the optional tables in its own
[test/dummy/db/migrate/20260821000001_create_aikotoba_optional_tables.rb](../test/dummy/db/migrate/20260821000001_create_aikotoba_optional_tables.rb)
(`test_helper.rb` puts both `test/dummy/db/migrate` and the engine's
`db/migrate` on `ActiveRecord::Migrator.migrations_paths`). Keep it in sync
when you change a commented-out block, or `test/dummy/db/schema.rb` will stop
matching what the engine ships.

**Destroy-safety**: `Account`'s optional `has_one` associations
(`confirmation_token`, `unlock_token`, `recovery_token`, `magic_link_token`)
and `Account::Session#refresh_token` are declared **without**
`dependent: :destroy`. Each instead has a guarded `before_destroy`. This is
deliberate, not an oversight — `dependent: :destroy` registers an
*unconditional* Rails callback that queries the association's table on every
parent destroy, which is exactly what raised `PG::UndefinedTable` for host
apps that had a feature's flag off and therefore never migrated its table
(e.g. `Web::Admin::AccountsController#destroy` failing on
`aikotoba_account_magic_link_tokens`). Ruby's `if` short-circuits the
right-hand side, so when the guard is false the association reader
(`confirmation_token`) is never called and the table is never queried.

The guard is **not** the feature flag. Gating on `confirmable?` and friends
covers the "never enabled, never migrated" case but breaks the opposite one:
a host app that used a feature and later switched its flag off still has rows
in that table, and skipping the cleanup strands them, so `Account#destroy!`
raises `ActiveRecord::InvalidForeignKey` (`PG::ForeignKeyViolation`) on the
orphaned child — something `dependent: :destroy` handled fine. The guards
therefore key off what actually determines whether there is anything to clean
up:

- `Account` declares each one with `optional_has_one :confirmation_token,
  foreign_key: "aikotoba_account_id", dependent: :destroy`, the macro from
  [app/models/concerns/aikotoba/optional_association.rb](../app/models/concerns/aikotoba/optional_association.rb).
  It resolves the table name off the association's reflection (no hardcoded
  strings) and gates on a `schema_cache.data_source_exists?` lookup: table
  missing ⇒ nothing was ever written, skip without querying; table present ⇒
  clean up, flag or no flag. Being schema-cached (negative results included)
  it costs at most one query per process — and, like anything schema-cached,
  a process that was already running when the migration was applied needs a
  restart to see the new table.
- `Account::Session` uses `origin_api?` instead, which is sharper: it is the
  exact mirror of `Session.start!`'s `session.build_refresh_token if
  session.origin_api?`, the only place a refresh token is ever created. A
  browser session therefore never touches `aikotoba_account_refresh_tokens`
  at all, and an api session always cleans its token up. Don't "simplify"
  this to `Aikotoba.api_authenticatable` — that reintroduces the stranded-row
  bug above, and refresh tokens live 30 days by default. Don't fold it into
  `optional_has_one` either, for consistency's sake: the
  macro only skips when the *table* is missing, so it would load the
  association on every browser sign-out to find nothing, and the case it
  additionally guards ("api session exists, its table doesn't") is
  unreachable because `start!` creates both in the same save. `Account` has
  no such invariant — an account legitimately has no token row — which is
  exactly why it needs the table lookup and `Session` doesn't.

`test/models/aikotoba/account_test.rb`'s `DestroyingOptionalTokens` class
guards all three properties (cleanup happens, cleanup survives a flag being
turned off, missing tables are never queried); the last one drops the tables
inside a rolled-back transaction, which works because SQLite has
transactional DDL.

A scope-based alternative (`has_one :confirmation_token, -> { confirmable? ? all : none }, ...`)
was tried and does **not** work, even though it looks like it should:
Rails builds the association's implicit foreign-key `WHERE aikotoba_account_id = ?`
clause *before* applying any custom scope (`AssociationScope#apply_scope` →
`PredicateBuilder#build` → `type_for_attribute` → `load_schema!`), so it
still needs the target table's `columns_hash` — and therefore the table
itself — even when the scope would ultimately resolve to `.none`. Only a
guard at the Ruby call-site (never invoking the association reader at all)
avoids touching the table. Don't re-attempt the scope version.

`dependent: :destroy` does **two** jobs, and dropping it costs both. The one
we want to lose is the callback. The one we need to keep is
`HasOneAssociation#remove_target!`, which reads `:dependent` out of the
reflection's options to clear the previous record when a new one replaces it
(triggered by `build_x_token` + `.save!`, not just by the association
writer). Without it, `replace` falls back to nullifying the old row's foreign
key and re-saving it, which fails the column's `NOT NULL` constraint and
raises `ActiveRecord::RecordNotSaved`.

So the caller writes `dependent: :destroy` as they would on any `has_one`, and
`optional_has_one` splits it: withheld from `has_one` so no callback is
registered, then set on the reflection afterwards so the runtime half still
works.

```ruby
dependent = options.delete(:dependent)
has_one(name, **options)
reflect_on_association(name).options[:dependent] = dependent
```

Order matters; passing it to `has_one` registers the callback we are avoiding.
Keeping `dependent:` at the call site rather than implying it is deliberate —
the declaration should say what happens on destroy, exactly like a plain
`has_one`. Only `:destroy` (or omitting it) is supported; anything else raises
`ArgumentError`, because honouring `:nullify` and friends would mean forwarding
them to `has_one` and getting the unconditional callback back, and silently
ignoring them would be worse.

The upshot is that `build_x_token` + `save!` behaves like a normal `has_one`
again, so each owning class's `create_token!` (`Confirmation`, `Lock`,
`Recovery`, `MagicLink`) stays plain Rails and there is no special
`rebuild_`/`recreate_` verb to remember. Verified on both CI Rails versions
(7.2 and 8.1); `Aikotoba::AccountTest::OptionalHasOne` plus the four
"regenerated token" controller tests are what catch it if a future Rails stops
honouring a post-declaration option.

Note that `create_x_token!` (Rails' own generated method) does **not** work
here, and never did — `SingularAssociation#_create_record` saves the new
record *before* `set_new_record` replaces the old one, so it hits the unique
index on the account FK. Use `build_x_token` + `save!`.

Turning a flag **on** without migrating its table is still unsupported: that
direction raises a real database error the first time the feature's code path
runs, by design (see the migration-layout paragraph above and the README's
Getting Start section). `Account#destroy!` is the one operation that stays
safe either way.

## Controller Conventions

- Base controller: All engine controllers inherit from [app/controllers/aikotoba/application_controller.rb](../app/controllers/aikotoba/application_controller.rb) which includes `EnabledFeatureCheckable` and `Scopable` and defines `aikotoba_controller?`.
- Overridable hooks: Session flow in [app/controllers/aikotoba/sessions_controller.rb](../app/controllers/aikotoba/sessions_controller.rb) exposes hook methods `before_sign_in_process`, `after_sign_in_process`, and `failed_sign_in_process` that apps can override via `config.to_prepare`.
- App-side example: The README shows aliasing `aikotoba_current_account` and implementing `authenticate_account!` in the host app controller.

## i18n

- Locale files: Default translations under [config/locales/en.yml](../config/locales/en.yml).
- UI texts, flash messages, and email contents are i18n-enabled so users can customize them according to their preferred language. Add or override translation files as needed.

## Developer Workflows

- Dependencies: Ruby on Rails `>= 6.1.4`; Argon2; optional Active Record Encryption (Rails 7+). Gem dependencies are declared in [aikotoba.gemspec](../aikotoba.gemspec) and dev/test gems in [Gemfile](../Gemfile).
- Lunch dummy app: Use the engine-mounted dummy app under [test/dummy](../test/dummy). To start the server:

  ```sh
  bundle install
  bin/rails s
  ```

- Run linter: User [Standard Ruby](https://github.com/standardrb/standard) with default config. To run:

  ```sh
  bundle install
  bundle exec standardrb --fix
  ```

- Run tests: Uses Minitest. Default task runs all tests from [Rakefile](../Rakefile).

  ```sh
  bundle install
  bin/rails test    # or: bundle exec rake test
  ```

- Test setup: Loads the engine-mounted dummy app ([test/dummy](../test/dummy)) and SimpleCov in [test/test_helper.rb](../test/test_helper.rb). System tests default to `rack_test`. Engine-specific auth helpers live in [lib/aikotoba/test/authentication_helper.rb](../lib/aikotoba/test/authentication_helper.rb) and are required from `test_helper`.
- Manual checks: Mount the engine in a host app or use the dummy app under `test/dummy`. Run `bin/rails` inside the dummy to verify routes and flows.
- The standard Rails Minitest framework is used; this is not RSpec.

## Where to Look First (Examples)

- Engine isolation: [lib/aikotoba/engine.rb](../lib/aikotoba/engine.rb)
- Scope-aware routes: [config/routes.rb](../config/routes.rb)
- Session lifecycle: [app/controllers/concerns/aikotoba/authenticatable.rb](../app/controllers/concerns/aikotoba/authenticatable.rb), [app/models/aikotoba/account/session.rb](../app/models/aikotoba/account/session.rb)
- Config and scopes: [lib/aikotoba.rb](../lib/aikotoba.rb)
- Sign-in UX: [app/controllers/aikotoba/sessions_controller.rb](../app/controllers/aikotoba/sessions_controller.rb), views under [app/views/aikotoba/sessions](../app/views/aikotoba/sessions)
- Tests Code:
  - Unit tests: [test/models/aikotoba/account/session_test.rb](../test/models/aikotoba/account/session_test.rb)
  - Controller tests: [test/controllers/aikotoba/authenticatable_test.rb](../test/controllers/aikotoba/authenticatable_test.rb)
  - System tests: [test/system/aikotoba/sessions_test.rb](../test/systems/navigation_test.rb)

## Notes

- Route availability (`sign_up`, `confirm`, `unlock`, `recover`) is gated by config (`Aikotoba.registerable`, `confirmable`, `lockable`, `recoverable`) via constraints.
- Deprecated config accessors (e.g., `Aikotoba.sign_in_path`) log deprecation and proxy to `default_scope`; prefer `Aikotoba.default_scope[:sign_in_path]`.

If any part is unclear or feels incomplete (e.g., preferred way to boot the dummy app in your environment, or project-specific override points), tell me and I’ll refine this doc.
