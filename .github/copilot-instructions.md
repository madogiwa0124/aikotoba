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

- Account: Validations, password hashing, and feature concerns in [app/models/aikotoba/account.rb](../app/models/aikotoba/account.rb). Passwords use Argon2 with pepper from config.
- Tokens: Confirmation/Unlock/Recovery tokens under [app/models/aikotoba/account/\*](../app/models/aikotoba/account) use `Account::Token` ([app/models/aikotoba/account/token.rb](../app/models/aikotoba/account/token.rb)).
- Token encryption: Optional deterministic encryption for `token` fields via `Aikotoba.encrypted_token`. See concern in [app/models/concerns/aikotoba/token_encryptable.rb](../app/models/concerns/aikotoba/token_encryptable.rb) and note AR 7+ requirement.

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
