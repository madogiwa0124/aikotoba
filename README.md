[![CI](https://github.com/madogiwa0124/aikotoba/actions/workflows/ci.yml/badge.svg)](https://github.com/madogiwa0124/aikotoba/actions/workflows/ci.yml)
[![Gem Version](https://badge.fury.io/rb/aikotoba.svg)](https://badge.fury.io/rb/aikotoba)

# Aikotoba

Aikotoba meaning password in Japanese.

Aikotoba is a Rails engine that makes it easy to implement simple email and password authentication.

**Motivation**

- Simple implementation using the Rails engine.
- Modern hashing algorithm.
- Separate the authentication logic from User.
- Implementation for multiple DB.
- Encrypting tokens using Active Record Encryption.

**Features**

- Authenticatable : Authenticate account using email and password.
- Registrable(optional) : Register an account using your email address and password.
- Confirmable(optional) : After registration, send an email with a token to confirm account.
- Lockable(optional) : Lock account if make a mistake with password more than a certain number of times.
- Recoverable(optional) : Recover account by resetting password.
- MagicLinkAuthenticatable(optional) : (experimental) Authenticate account by clicking a one-time sign-in link sent by email, no password required.

[For more information](#features)

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'aikotoba'
```

Aikotoba requires Rails 8.1 or later.

Emails (confirmation, unlock, password recovery, magic link) are sent with `deliver_later` after the surrounding transaction commits. Configure a persistent Active Job backend in production: the default `:async` adapter loses queued emails when the process restarts.

## Usage

### Getting Start

Aikotoba use `Aikotoba::Account` for authentication. Add it to the migration for `Aikotoba::Account`.

```sh
$ bin/rails aikotoba:install:migrations
```

The copied migration creates the always-required tables (accounts / password hashes /
sessions) and carries one **commented-out** block per optional feature: Confirmable,
Lockable, Recoverable and MagicLinkAuthenticatable. All four
default to off (see [Configuration](#configuration)), so nothing is created for them
unless you ask for it. Uncomment the block for each feature you enable, then migrate:

```sh
$ bin/rails db:migrate
```

If you enable a feature *later*, after this migration has already run, uncommenting it is
not enough -- add the same `create_table` in a new migration of your own instead.

Either way, keeping "flag is on" and "its table exists" in sync is the host app's
responsibility. If a feature's flag is on without its table, you'll hit real database
errors (e.g. `PG::UndefinedTable`) the first time that feature's code path runs --
Aikotoba does not, and cannot, guard against that direction.

The reverse direction *is* safe: if a feature's table was never created, Aikotoba never
queries it on `Account#destroy!` or session revocation, so it's fine for that table to
not exist at all. Destroying accounts and revoking sessions also keeps working if you
enable a feature, use it, and later turn its flag back off -- the leftover token rows are
still cleaned up rather than left behind as orphans.

Mount `Aikotoba::Engine` your application.

```ruby
Rails.application.routes.draw do
  mount Aikotoba::Engine => "/"
end
```

Aikotoba enabled routes for registration(`/sign_up`) and authentication(`/sign_in`).

include `Aikotoba::Authenticatable` to the controller(ex. `ApplicationController`) use authentication.

```ruby
class ApplicationController < ActionController::Base
  include Aikotoba::Authenticatable

  # NOTE: You can implement the get authenticated account process as follows.
  alias_method :current_account, :aikotoba_current_account
  helper_method :current_account

  # NOTE: You can implement the authorization process as follows
  def authenticate_account!
    return if current_account
    redirect_to aikotoba.new_session_path, flash: {alert: "Oops. You need to Signed up or Signed in." }
  end
end
```

## Features

### Authenticatable

Authenticate an account using email and password.

| HTTP Verb | Path      | Overview                                  |
| --------- | --------- | ----------------------------------------- |
| GET       | /sign_in  | Display sign in page.                     |
| POST      | /sign_in  | Create a login session by authenticating. |
| DELETE    | /sign_out | Clear aikotoba login session.             |

Aikotoba enable helper methods for authentication. The method name can be changed by `alias_method`.

- `aikotoba_current_account` : Returns the logged in instance of `Aikotoba::Account`.

#### Redirecting back to the originally requested page after sign in

By default, a successful sign in always redirects to `after_sign_in_path`. To
instead send the account back to the page it was trying to reach before being
redirected to sign in, replace the `redirect_to` in your `authenticate_account!`
(see [Getting Start](#getting-start)) with `aikotoba_request_authentication`,
which takes the same options as `redirect_to` (modeled on the Rails
authentication generator's `request_authentication`):

```ruby
def authenticate_account!
  return if current_account
  aikotoba_request_authentication flash: {alert: "Oops. You need to Signed up or Signed in." }
end
```

It stores the current `request.fullpath` in the session, keyed per scope,
redirects to the scope's sign in page, and after the next successful sign in
redirects back there, falling back to `after_sign_in_path` when nothing was
stored. Only a plain page visit (a non-XHR HTML `GET`) is stored, a
protocol-relative path (`//host/...`) is never stored, so it can't become an
open redirect, and it's used at most once. It also applies to [MagicLinkAuthenticatable](#experimental-magiclinkauthenticatable)
sign in.

Aikotoba deliberately doesn't capture this from the `Referer` of `GET /sign_in`:
browsers keep the original `Referer` across a redirect, so it points at the
page that *linked to* the protected page rather than the protected page itself.

### Registrable

To enable it, set `config.registerable` to `true` in `Aikotoba.configure`. (It is enabled by default.)

```ruby
Aikotoba.configure do |config|
  config.registerable = true
end
```

Register an account using email and password.

| HTTP Verb | Path     | Overview              |
| --------- | -------- | --------------------- |
| GET       | /sign_up | Display sign up page. |
| POST      | /sign_up | Create an account.    |

The built-in sign up is meant for the simple case: an email and password account in a scope without `authenticate_for`. For anything more involved, such as extra form fields, creating a profile model together with the account, or creating accounts for a scope that sets `authenticate_for` (see [Filtering by authenticate target type](#filtering-by-authenticate-target-type)), write your own controller on top of the model methods instead of extending the built-in one:

```ruby
class SignUpsController < ApplicationController
  def create
    @account = Aikotoba::Account.build_by(attributes: {email: sign_up_params[:email], password: sign_up_params[:password].to_s})
    ActiveRecord::Base.transaction do
      @account.authenticate_target = Profile.create!(nickname: sign_up_params[:nickname])
      # Saves the account and, when confirmable, issues a confirmation token.
      # The email is enqueued only after this transaction commits.
      @account.register!
    end
    redirect_to aikotoba.new_session_path
  rescue ActiveRecord::RecordInvalid
    render :new, status: :unprocessable_entity
  end

  private

  def sign_up_params
    params.require(:account).permit(:email, :password, :nickname)
  end
end
```

Pass `password` even when it is blank (as above): `build_by` only builds a password when the key is present, so dropping it would save an account no one can sign in to. If the controller creates accounts for a restricted scope, such as Admins, put it behind your own authorization instead of exposing it publicly.

The password is stored as a hash in [Argon2](https://github.com/technion/ruby-argon2), in a separate `Aikotoba::Account::PasswordHash` record (table `aikotoba_account_password_hashes`) rather than on `Aikotoba::Account` itself, so `Account` does not depend on password-based authentication.

### Confirmable

To enable it, set `config.confirmable` to `true` in `Aikotoba.configure`.

```ruby
Aikotoba.configure do |config|
  config.confirmable = true
end
```

Aikotoba enable routes for confirmation account. Also, when account registers, a confirmation email is sent to the email address. Only accounts that are confirmed will be authenticated.

| HTTP Verb | Path            | Overview                               |
| --------- | --------------- | -------------------------------------- |
| GET       | /confirm        | Display page for create confirm token. |
| POST      | /confirm        | Create a confirm token to account.     |
| GET       | /confirm/:token | Confirm account by token.              |

### Lockable

To enable it, set `config.lockable` to `true` in `Aikotoba.configure`.

```ruby
Aikotoba.configure do |config|
  config.lockable = true
end
```

Aikotoba enables a route to unlock an account. Also, if the authentication fails a certain number of times, the account will be locked. Only accounts that are not locked will be authenticated.

| HTTP Verb | Path           | Overview                              |
| --------- | -------------- | ------------------------------------- |
| GET       | /unlock        | Display page for create unlock token. |
| POST      | /unlock        | Create a unlock token to account.     |
| GET       | /unlock/:token | Unlock account by token.              |

### Recoverable

To enable it, set `config.recoverable` to `true` in `Aikotoba.configure`.

```ruby
Aikotoba.configure do |config|
  config.recoverable = true
end
```

Aikotoba enables a route to recover an account by password reset.

| HTTP Verb | Path            | Overview                                            |
| --------- | --------------- | --------------------------------------------------- |
| GET       | /recover        | Display page for create recover token.              |
| POST      | /recover        | Create a recover token to account.                  |
| GET       | /recover/:token | Display page for recover account by password reset. |
| PATCH     | /recover/:token | Recover account by password reset.                  |

### (Experimental) MagicLinkAuthenticatable

To enable it, set `config.magic_link_authenticatable` to `true` in `Aikotoba.configure`.

```ruby
Aikotoba.configure do |config|
  config.magic_link_authenticatable = true
end
```

Aikotoba enables a route to sign in via a one-time link sent by email —
no password needed. This works for accounts that were never given a
password at all (`Aikotoba::Account.create!(email: "sample@example.com")`),
since password storage is owned entirely by `Aikotoba::Account::PasswordHash`
and `Account` itself has no password of its own. Signing in works exactly
like `Authenticatable`, just entered by clicking the link instead of
submitting the sign-in form.

| HTTP Verb | Path               | Overview                                       |
| --------- | ------------------ | ----------------------------------------------- |
| GET       | /magic_link        | Display page for requesting a sign in link.     |
| POST      | /magic_link        | Send a one-time sign in link to the account.    |
| GET       | /magic_link/:token | Verify the link and sign in.                    |

### Rate Limiting

Aikotoba provides built-in rate limiting for email-sending endpoints to prevent email bombing attacks.

Rate limiting is available for:

- **Confirmation token requests** (`/confirm` POST endpoint)
- **Unlock token requests** (`/unlock` POST endpoint)
- **Password recovery token requests** (`/recover` POST endpoint)

By default, rate limiting is disabled (empty configuration). To enable it, configure the respective options:

```ruby
Aikotoba.configure do |config|
  config.confirmation_rate_limit_options = {
    to: 10,
    within: 1.hour,
    by: -> { request.params.dig(:account, :email).presence || request.remote_ip },
    only: :create
  }
end
```

When rate limiting is triggered, requests that exceed the limit will receive a 429 (Too Many Requests) response.

For detailed configuration examples and options, see the [Configuration](#configuration) section below.

### Multiple Scopes

Aikotoba supports multiple scopes.

You can add a scope with `config.add_scope` in `Aikotoba.configure`. For example, the following code adds an `admin` scope. Unspecified values will be copied from the `default` scope.

```ruby
Aikotoba.configure do |config|
  config.add_scope(:admin, {
    session_key: "aikotoba_admin_session_token",
    root_path: "/admin",
    sign_in_path: "/admin/sign_in",
    sign_up_path: "/admin/sign_up",
    after_sign_in_path: "/admin/sensitives",
    after_sign_out_path: "/admin/sign_in",
    sign_out_path: "/admin/sign_out",
    confirm_path: "/admin/confirm",
    unlock_path: "/admin/unlock",
    recover_path: "/admin/recover",
    magic_link_path: "/admin/magic_link"
  })
end
```

As shown below, you can perform separate authentication with `/sign_in` and `/admin/sign_in`.

```sh
$ bin/rails routes
Routes for Aikotoba::Engine:
                         Prefix Verb   URI Pattern                     Controller#Action
                    new_session GET    /sign_in(.:format)              aikotoba/sessions#new
              admin_new_session GET    /admin/sign_in(.:format)        aikotoba/sessions#new
```

The scope is determined dynamically by the root path. For example, when accessing `/admin/sign_in`, the `admin` scope is selected.

To automatically switch scopes and get paths, use the `Aikotoba::Scopable#aikotoba_scoped_path` helper method.

```ruby
include Aikotoba::Scopable

helper_method :aikotoba_scoped_path

aikotoba_scoped_path(:new_session)
#=> "/sign_in" (if current scope is :default)
#=> "/admin/sign_in" (if current scope is :admin)
```

## Configuration

Configure Aikotoba in one `Aikotoba.configure` block, in an initializer such as `config/initializers/aikotoba.rb`. Once the block has run, Aikotoba checks the scopes against every setting it made (see [Scope Configuration Details](#scope-configuration-details)). Read a setting with `Aikotoba.xxx`, e.g. `Aikotoba.confirmable`.

Write `authenticate_for` as a string (`"Admin"`, not `Admin`): your app's classes can't be autoloaded while initializers run.

The `Aikotoba.xxx = ...`, `Aikotoba.add_scope` and `Aikotoba.default_scope=` writers used before `configure` existed still work, but are deprecated and will be removed in 1.0: each call logs a deprecation warning through `Aikotoba.deprecator`, which is registered in `Rails.application.deprecators`. Move them into `Aikotoba.configure`.

The following configuration parameters are supported:

```ruby
require 'aikotoba'

Aikotoba.configure do |config|
  # ============================================
  # Global settings
  # ============================================

  config.parent_controller = "ApplicationController"
  config.parent_mailer = "ActionMailer::Base"
  config.mailer_sender = "from@example.com"
  config.email_format = /\A[^\s]+@[^\s]+\z/
  config.password_pepper = "aikotoba-default-pepper"
  config.password_length_range = 8..100
  config.session_expiry = 7.days

  # for registerable
  config.registerable = true

  # for confirmable
  config.confirmable = false
  config.confirmation_token_expiry = 1.day

  # for lockable
  config.lockable = false
  config.max_failed_attempts = 10
  config.unlock_token_expiry = 1.day

  # for Recoverable
  config.recoverable = false
  config.recovery_token_expiry = 4.hours

  # for (Experimental) MagicLinkAuthenticatable
  config.magic_link_authenticatable = false
  config.magic_link_token_expiry = 15.minutes

  # ============================================
  # Rate Limiting
  # ============================================
  # Rate limiting protects email-sending endpoints (confirm, unlock, recover) from email bombing attacks.
  # Default (empty hash): no rate limiting

  # Requires Rails 8.0+ to use the built-in rate_limit feature.
  #
  # Configuration format: { to: <max_requests>, within: <time_duration>, by: <identifier_proc>, only: <action> }
  #
  # SECURITY RECOMMENDATION:
  # Use .dig() with fallback to prevent nil errors and ensure rate limiting always works:
  #   by: -> { request.params.dig(:account, :email).presence || request.remote_ip }
  #
  # This ensures:
  # - Invalid or missing email params don't bypass rate limiting
  # - Fallback to IP address when email is not provided
  # - Repeated emails to the same address are throttled (this keys on the email, so it does not limit
  #   requests spread across many different addresses)
  #
  # Examples:

  # Limit confirmation token requests to 10 per hour, per email address (with IP fallback)
  config.confirmation_rate_limit_options = {
    to: 10,
    within: 1.hour,
    by: -> { request.params.dig(:account, :email).presence || request.remote_ip },
    only: :create
  }

  # Limit unlock token requests to 5 per hour, per email address (stricter for security)
  config.unlock_rate_limit_options = {
    to: 5,
    within: 1.hour,
    by: -> { request.params.dig(:account, :email).presence || request.remote_ip },
    only: :create
  }

  # Limit recovery token requests to 3 per hour, per email address (most strict for password recovery)
  config.recovery_rate_limit_options = {
    to: 3,
    within: 1.hour,
    by: -> { request.params.dig(:account, :email).presence || request.remote_ip },
    only: :create
  }

  # Limit magic link requests to 5 per hour, per email address
  config.magic_link_rate_limit_options = {
    to: 5,
    within: 1.hour,
    by: -> { request.params.dig(:account, :email).presence || request.remote_ip },
    only: :create
  }

  # Rate limiting by IP address only (simpler, but less precise)
  # config.confirmation_rate_limit_options = {
  #   to: 20,
  #   within: 1.hour,
  #   by: -> { request.remote_ip },
  #   only: :create
  # }

  # ============================================
  # Scope settings
  # ============================================

  # for Default Scope
  # You can override only the necessary keys.
  config.default_scope = {
    authenticate_for: nil,  # No restriction for default scope
    session_key: "aikotoba_session_token",
    root_path: "/",
    sign_in_path: "/sign_in",
    sign_out_path: "/sign_out",
    sign_up_path: "/sign_up",
    confirm_path: "/confirm",
    unlock_path: "/unlock",
    recover_path: "/recover",
    magic_link_path: "/magic_link",
    after_sign_in_path: "/sensitives",
    after_sign_out_path: "/sign_in"
  }

  # for Additional Scopes
  config.add_scope(:admin, {
    authenticate_for: "Admin",  # Restrict authentication to Admin accounts
    session_key: "aikotoba_admin_session_token",
    root_path: "/admin",
    sign_in_path: "/admin/sign_in",
    sign_out_path: "/admin/sign_out",
    confirm_path: "/admin/confirm",
    unlock_path: "/admin/unlock",
    recover_path: "/admin/recover",
    magic_link_path: "/admin/magic_link",
    after_sign_in_path: "/admin/sensitives",
    after_sign_out_path: "/admin/sign_in"
  })
end
```

### Scope Configuration Details

`config.default_scope=` **merges** the provided hash into the existing default scope (does not replace):

```ruby
Aikotoba.configure do |config|
  # Single key update
  config.default_scope[:sign_in_path] = "/custom"

  # Multiple keys update (recommended for bulk changes)
  config.default_scope = {
    sign_in_path: "/custom_sign_in",
    after_sign_in_path: "/dashboard"
  }
  # Other keys (root_path, session_key, etc.) remain unchanged
end
```

Both approaches are valid. Use direct key assignment for single changes, or use `default_scope=` for updating multiple keys at once.

#### Filtering by authenticate target type

You can restrict authentication to specific target types by setting `authenticate_for`:

```ruby
Aikotoba.configure do |config|
  config.add_scope(:admin, {
    authenticate_for: "Admin",  # Only Admin accounts can sign in to this scope
    root_path: "/admin",
    sign_in_path: "/admin/sign_in",
    # ...
  })
end
```

When `authenticate_for` is set, only accounts with matching `authenticate_target_type` will authenticate successfully in that scope.
This is useful for separating authentication between different user types (e.g., Admin vs User).

The same rule applies to the scope's confirm, unlock, password reset and magic link endpoints: they only send emails to, and accept tokens from, accounts with a matching `authenticate_target_type`. A scope without `authenticate_for` handles every account, just as it lets every account sign in.

The links in those emails point to the account's own scope: the scope whose `authenticate_for` matches the account's `authenticate_target_type`, or the default scope if none does. This holds wherever the email was requested from, since it is rendered in a background job with no request to tell.

An added scope must set its own `root_path`: an absolute path other than `"/"`, such as `"/admin"`. Aikotoba treats every request under a scope's `root_path` as that scope's, so a scope at `"/"` would take every request, your app's own pages included, away from the default scope, and a malformed one such as `"admin"` would match none, not even its own pages. `add_scope` copies `root_path: "/"` from the default scope, so leaving it unset raises `Aikotoba::Errors::InvalidScopeConfiguration` too.

Each `authenticate_for` value may be set on only one scope, so that an account's type maps to exactly one scope. Otherwise `Aikotoba::Errors::InvalidScopeConfiguration` is raised when the scope is added, or at boot once your initializers have run. Keep in mind that `add_scope` copies unspecified keys from the default scope, including `authenticate_for`. If the default scope sets one, give every added scope its own `authenticate_for` (`nil` for an unrestricted scope).

The same copying applies to paths, but they need no extra care. Aikotoba decides which scope a request belongs to by its `root_path`, so it draws each route path of a scope under that scope's `root_path`. A path already under `root_path` (`/admin/sign_in` in an `/admin` scope) is used as is. Any other path is prefixed with `root_path`: an unset `magic_link_path` inherits `/magic_link` from the default scope and is drawn as `/admin/magic_link`, and `/magic` becomes `/admin/magic`. Redirect targets such as `after_sign_in_path` are not prefixed. If you set an absolute path outside `root_path` on the scope itself (say `magic_link_path: "/magic"` in an `/admin` scope), it is still drawn as `/admin/magic`, and Aikotoba logs a warning at boot, since you may have meant `/magic` as is. Write `/admin/magic` or the relative `magic` to silence it.

**Note:** A scope with `authenticate_for` has no sign up, even when `Aikotoba.registerable` is enabled: no route is generated for its `sign_up_path`, and its sign in page shows no sign up link. Its accounts need an `authenticate_target` of that type, which the generic sign up form can't create, and a public form that could would let anyone create, say, an Admin account. Create these accounts yourself (from the console, a seed, an invitation flow, or your own controller as described in [Registrable](#registrable)):

```ruby
admin = Admin.create!(nickname: "admin")
Aikotoba::Account.create_by!(attributes: {email: "admin@example.com", password: "password", authenticate_target: admin})
```

`create_by!` only saves the account. With Confirmable enabled it starts unconfirmed and can't sign in yet:

- To send the confirmation email, build it and call `register!` instead: `Aikotoba::Account.build_by(attributes: {email: "admin@example.com", password: "password", authenticate_target: admin}).register!`
- If you create the account yourself and trust the address, mark it confirmed with `account.confirm!`.

## Tips

### Customize Message

All Messages are managed by `i18n` and can be freely overridden.

### Manually create an `Aikotoba::Account` for authentication.

By running the following script, you can hash and store passwords.

```ruby
Aikotoba::Account.create_by!(attributes: {email: "sample@example.com", password: "password"})
Aikotoba::Account::PasswordHash.authenticate_by(attributes: {email: "sample@example.com", password: "password"})
# => created account instance.
```

To update an existing account's email and/or password together in one validated save, use `#update_by!` (or the non-bang `#update_by`), the update-side counterpart to `.create_by!`/`.build_by`:

```ruby
account.update_by!(attributes: {email: "new@example.com", password: "new_password"})
```

### Create other model with `Aikotoba::Account`.

You can override `Aikotoba::AccountsController#after_create_account_process` to create the other models together. Sign up only exists in scopes without `authenticate_for` (see [Filtering by authenticate target type](#filtering-by-authenticate-target-type)).

```ruby
require 'aikotoba'

Rails.application.config.to_prepare do
  Aikotoba::AccountsController.class_eval do
    def after_create_account_process
      user = User.new(nickname: "foo")
      @account.authenticate_target = user
      user.save!
      @account.save!
    end
  end
end

class Profile < ApplicationRecord
  has_one :account, class_name: 'Aikotoba::Account', as: :authenticate_target
end

class Admin < ApplicationRecord
  has_one :account, class_name: 'Aikotoba::Account', as: :authenticate_target
end
```

Then, you can get the associated model from `Aikotoba::Account` instance.

```ruby

current_account.profile #=> Profile instance
profile.account #=> Aikotoba::Account instance

current_account.admin #=> Admin instance
admin.account #=> Aikotoba::Account instance
```

### Do something on before, after, failure.

Controllers provides methods to execute the overridden process.

For example, if you want to record an error log when the account creation fails, you can do the following.

```ruby
require 'aikotoba'

Rails.application.config.to_prepare do
  Aikotoba::AccountsController.class_eval do
    def failed_create_account_process(e)
      logger.error(e)
    end
  end
end
```

### Using encrypted token

Tokens can be encrypted using Active Record Encryption, introduced in Active Record 7 and later.
To use it, enable Aikotoba.encipted_token in the initializer.

```ruby
Aikotoba.configure do |config|
  config.encrypted_token = true
end
```

### How to identify the controller provided.

The controller provided by Aikotoba is designed to inherit from `Aikotoba::ApplicationController`.

Therefore, when implementing authorization based on login status, you can disable only the controllers provided by Aikotoba as follows.

```ruby
class ApplicationController < ApplicationController
  include Aikotoba::Authenticatable

  alias_method :current_account, :aikotoba_current_account

  before_action :authenticate_account!, unless: :aikotoba_controller?

  def authenticate_account!
    return if current_account
    redirect_to aikotoba.new_session_path, flash: {alert: "Oops. You need to Signed up or Signed in." }
  end

  private

  def aikotoba_controller?
    is_a?(::Aikotoba::ApplicationController)
  end
end
```

### Testing

You can use a helper to login/logout by Aikotoba.
:warning: It only supports rack testing.

```ruby
require "aikotoba/test/authentication_helper"
require "test_helper"

class HelperTest < ActionDispatch::SystemTestCase
  include Aikotoba::Test::AuthenticationHelper::System
  driven_by :rack_test

  def setup
    email, @password = ["email@example.com", "password"]
    @account = ::Aikotoba::Account.build_by(attributes: {email: email, password: @password})
    @account.save
  end

  test "sign_in by helper" do
    aikotoba_sign_in(@account, password: @password)
    visit "/sensitives"
    assert_selector "h1", text: "Sensitive Page"
    click_on "Sign out"
    assert_selector ".message", text: "Signed out."
  end

  test "sign_out by helper" do
    aikotoba_sign_in(@account, password: @password)
    visit "/sensitives"
    aikotoba_sign_out
    visit "/sensitives"
    assert_selector "h1", text: "Sign in"
    assert_selector ".message", text: "Oops. You need to Signed up or Signed in."
  end
end
```

## Contributing

Bug reports and pull requests are welcome on GitHub.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
