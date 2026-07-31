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
