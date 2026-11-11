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
- TwoFactorAuthenticatable(optional, per scope) : (experimental) After a correct password, require a one-time code sent by email before signing in.

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
Lockable, Recoverable, MagicLinkAuthenticatable and TwoFactorAuthenticatable. All of them
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

### (Experimental) TwoFactorAuthenticatable

Turn it on per scope, with `two_factor_authenticatable: true`, and uncomment the `aikotoba_account_email_otp_codes` table in the migration:

```ruby
Aikotoba.configure do |config|
  # Every account signing in to the default scope
  config.default_scope[:two_factor_authenticatable] = true

  # Or only the admins
  config.add_scope(:admin, {
    root_path: "/admin",
    session_key: "aikotoba_admin_session_token",
    authenticate_for: "Admin",
    two_factor_authenticatable: true
  })
end
```

A correct password then no longer signs in. Aikotoba emails a 6-digit code and sends the user to the scope's `two_factor_path`, and the login session starts only once the code is entered there. Until then there is no `Aikotoba::Account::Session`, so `aikotoba_current_account` is `nil`.

| HTTP Verb | Path        | Overview                                      |
| --------- | ----------- | --------------------------------------------- |
| GET       | /two_factor | Display page for entering the emailed code.   |
| POST      | /two_factor | Verify the code and sign in.                  |

- The code expires after `config.email_otp_code_expiry` (10 minutes) and can be tried `config.email_otp_max_failed_attempts` times (5). After that the user signs in with the password again, which sends a new code; signing in again also replaces a code that hasn't been used.
- **A wrong code is a failed sign in.** It counts towards the account's `failed_attempts` and, with [Lockable](#lockable), locks the account like a wrong password does. A correct password doesn't reset `failed_attempts` in a scope that requires a code, only a correct code does, so someone who knows the password can't get a fresh set of guesses by signing in again.
- Which account is signing in is kept in the Rails session, for the same time as the code. The code and the attempts made against it are kept in the database, since a cookie session could be sent again to undo an attempt count or to reuse a code.
- [Magic link](#experimental-magiclinkauthenticatable) sign in doesn't ask for a code: having the email is what both prove.

**An email code is a weaker second factor than an authenticator app or a passkey.** It protects an account whose password has leaked, but not one whose mailbox is taken over: with [Recoverable](#recoverable), whoever controls the mailbox can reset the password and receive the code. NIST SP 800-63B does not accept email for out-of-band authentication ([§5.1.3.1](https://pages.nist.gov/800-63-3/sp800-63b.html#-5131-out-of-band-authenticators)). Use it where the users' mailboxes are themselves protected with two-factor authentication.

If you write your own sign in controller, check the password with `reset_failed_attempts: !aikotoba_two_factor_required?` and call `aikotoba_begin_sign_in` instead of `aikotoba_sign_in`. It signs in and returns the session when the scope doesn't require a code. When it does, it sends the code and returns `nil`, and you redirect to the code page:

```ruby
class SignInsController < ApplicationController
  def create
    account = Aikotoba::Account::PasswordHash.authenticate_by(
      attributes: {email: params[:email], password: params[:password]},
      target_type_name: Aikotoba.default_scope.authenticate_for,
      reset_failed_attempts: !aikotoba_two_factor_required?
    )
    return head(:unprocessable_entity) unless account

    if aikotoba_begin_sign_in(account)
      redirect_to "/sensitives"
    else
      redirect_to aikotoba.new_two_factor_path
    end
  end
end
```

`aikotoba_sign_in` still signs in straight away, whatever the scope requires.

### Rate Limiting

Aikotoba can rate limit the endpoints anyone can call without an account, using Rails' built-in [`rate_limit`](https://api.rubyonrails.org/classes/ActionController/RateLimiting/ClassMethods.html):

| Setting                            | Endpoint                 | Against                                      |
| ---------------------------------- | ------------------------ | -------------------------------------------- |
| `sign_in_rate_limit_options`       | `POST /sign_in`          | credential stuffing, password guessing       |
| `registration_rate_limit_options`  | `POST /sign_up`          | probing which emails have an account         |
| `confirmation_rate_limit_options`  | `POST /confirm`          | email bombing                                |
| `unlock_rate_limit_options`        | `POST /unlock`           | email bombing                                |
| `recovery_rate_limit_options`      | `POST /recover`          | email bombing                                |
| `magic_link_rate_limit_options`    | `POST /magic_link`       | email bombing                                |
| `two_factor_rate_limit_options`    | `POST /two_factor`       | guessing the emailed code                    |

Every setting is off (`{}`) by default. Each takes the options of `rate_limit` (`to:`, `within:`, `by:`, `with:`, `store:`, `name:`, `only:`, `except:`):

```ruby
Aikotoba.configure do |config|
  # Credential stuffing tries many accounts from the same addresses, so key sign in by IP.
  config.sign_in_rate_limit_options = {to: 20, within: 10.minutes, by: -> { request.remote_ip }}
  config.registration_rate_limit_options = {to: 10, within: 1.hour, by: -> { request.remote_ip }}

  # Token emails: per address, so one inbox can't be flooded.
  config.confirmation_rate_limit_options = {
    to: 10,
    within: 1.hour,
    by: -> { request.params.dig(:account, :email).presence || request.remote_ip }
  }
end
```

**What `by:` keys on is a trade-off, not a detail.** A request over the limit is refused whoever sends it, so the key decides who gets blocked:

- **By IP** (`request.remote_ip`, Rails' default) limits one client however many accounts it tries, which is what stops credential stuffing and enumeration through sign up. It doesn't stop an attacker spreading requests over many addresses (a botnet, or an IPv6 range), and it throttles everyone behind one shared address (an office NAT, a mobile carrier) together. Behind a load balancer or CDN, `remote_ip` is only the client's address if [trusted proxies](https://api.rubyonrails.org/classes/ActionDispatch/RemoteIp.html) are set up; otherwise every request counts as the proxy's.
- **By email** limits one account however many clients try it. That is the right key for the token emails, where the victim is the inbox. For sign in it is a denial-of-service lever: anyone who knows an address can keep its owner from signing in by sending wrong passwords for it, the same lever [Lockable](#lockable) gives, and it does nothing against an attacker trying one password per account. Don't key sign in by email alone.
- The `email.presence || remote_ip` fallback used for the token emails keeps a request without an email from skipping the limit, but still counts per address, so it does not limit requests spread across many addresses.

Things to know before turning it on:

- **Only `create` is limited** unless the options set `only:` or `except:`. So showing a form, signing out and following a token link are never counted or blocked. Sign in counts every attempt, successful ones included, so leave room for users who mistype.
- **A limited request raises `ActionController::TooManyRequests`** on every endpoint, which Rails answers with a 429. Those who see that page are mostly not attackers but users caught by the limit: everyone behind an IP an attacker uses, or the owner of an inbox someone is flooding who asks for their own reset. **Rails doesn't generate a `public/429.html`**, so in production, where the error page comes from `public/`, they get an empty page unless you add one. Add `public/429.html`, or answer them from your `ApplicationController`, which Aikotoba's controllers inherit, so one handler covers every endpoint (and your own controllers' `rate_limit`):

  ```ruby
  class ApplicationController < ActionController::Base
    rescue_from ActionController::TooManyRequests do
      render plain: "Too many requests. Please try again later.", status: :too_many_requests
    end
  end
  ```

  To respond differently on one endpoint, set `with:` in its options.
- **Counters are shared between scopes**: `/sign_in` and `/admin/sign_in` count against the same limit. The default scope signs in every account, so a counter per scope would give an attacker one more budget against the same accounts. To count each scope on its own anyway, put the scope in the key: `by: -> { [aikotoba_scope, request.remote_ip].join(":") }`. A subclass of an Aikotoba controller that your app routes itself counts against the same limit as the engine's, unless the options set `scope:`.
- **A limited request reports no Aikotoba event.** It is refused before the password is checked, so a refused sign in is not a `sign_in_failed`. If you watch `sign_in_failed` to notice attacks, also subscribe to Rails' [`rate_limit.action_controller`](https://guides.rubyonrails.org/active_support_instrumentation.html) notification, or an attack shows up as failures that stop once the limit is reached:

  ```ruby
  ActiveSupport::Notifications.subscribe("rate_limit.action_controller") do |event|
    next unless event.payload[:scope].start_with?("aikotoba/")

    Rails.logger.warn("Rate limited #{event.payload[:scope]}: #{event.payload[:count]} requests in #{event.payload[:within].inspect}")
  end
  ```
- **Counters live in the cache store** (`config.cache_store`, or `store:`). It has to be shared by every process and server, such as Solid Cache or Redis: with a per-process `:memory_store`, each process counts on its own, so the real limit is `to:` times the number of processes. `:null_store` (the default in the test environment) counts nothing, so nothing is ever limited.
- The options are read when the controller class loads, so a change needs a restart (or, in tests, reloading the controller).

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

`root_path`, like every route path of a scope, is relative to where `Aikotoba::Engine` is mounted. With `mount Aikotoba::Engine => "/auth"`, the `admin` scope above serves `/auth/admin/sign_in`. The same holds for your app's own controllers that include `Aikotoba::Authenticatable`: a page at `/auth/admin/sensitives` is in the `admin` scope, and one at `/admin/sensitives`, outside the mount point, is in the `default` scope. Redirect targets such as `after_sign_in_path` are paths in your app, not relative to the mount point.

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

  # for (Experimental) TwoFactorAuthenticatable (turned on per scope with two_factor_authenticatable)
  config.email_otp_code_expiry = 10.minutes
  config.email_otp_max_failed_attempts = 5

  # ============================================
  # Rate Limiting
  # ============================================
  # Off ({}) by default. Takes the options of Rails' rate_limit. Limits only :create unless only:/except:
  # is set. See the Rate Limiting section for which by: to choose and what store it needs.

  # Sign in, per IP: against credential stuffing. Don't key it by email alone, which lets anyone
  # block an account's sign in by sending wrong passwords for it.
  config.sign_in_rate_limit_options = {to: 20, within: 10.minutes, by: -> { request.remote_ip }}

  # Sign up, per IP: caps how many emails can be checked for an existing account.
  config.registration_rate_limit_options = {to: 10, within: 1.hour, by: -> { request.remote_ip }}

  # Token emails, per email address with an IP fallback: against flooding one inbox.
  config.confirmation_rate_limit_options = {
    to: 10,
    within: 1.hour,
    by: -> { request.params.dig(:account, :email).presence || request.remote_ip }
  }
  config.unlock_rate_limit_options = {
    to: 5,
    within: 1.hour,
    by: -> { request.params.dig(:account, :email).presence || request.remote_ip }
  }
  config.recovery_rate_limit_options = {
    to: 3,
    within: 1.hour,
    by: -> { request.params.dig(:account, :email).presence || request.remote_ip }
  }
  config.magic_link_rate_limit_options = {
    to: 5,
    within: 1.hour,
    by: -> { request.params.dig(:account, :email).presence || request.remote_ip }
  }

  # Entering the emailed code, per IP. The attempts per code and Lockable limit it per account already.
  config.two_factor_rate_limit_options = {to: 20, within: 10.minutes, by: -> { request.remote_ip }}

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
    two_factor_authenticatable: false,  # Require an emailed code after the password
    two_factor_path: "/two_factor",
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
    session_key: "aikotoba_admin_session_token",
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

An added scope must set its own `root_path`: an absolute path other than `"/"`, such as `"/admin"`. Aikotoba treats every request under a scope's `root_path` as that scope's, so a scope at `"/"` would take every request, your app's own pages included, away from the default scope, and a malformed one such as `"admin"` would match none, not even its own pages. `add_scope` copies `root_path: "/"` from the default scope, so leaving it unset raises `Aikotoba::Errors::InvalidScopeConfiguration` too. Requests go to the first added scope whose `root_path` covers them, and every route of a scope must be served as that scope. So an added scope may not have the same `root_path` as another, or one under a scope added before it (`"/admin/super"` added after `"/admin"`, whose requests would all go to `"/admin"`; added before it, it keeps its own). Nor may a path of the default scope be under an added scope's `root_path` (a default `sign_in_path` of `"/admin/login"` with an `"/admin"` scope).

An added scope must also set its own `session_key`, the name of its session cookie, different from every other scope's. Two scopes sharing one would read each other's cookie: a scope without `authenticate_for` would accept the other's sessions, so an Admin signed in to the `admin` scope would be signed in to the default scope too, and a scope with one would delete the cookie of a session it doesn't accept, signing the account out of the other scope. `add_scope` copies `session_key` from the default scope, so leaving it unset raises `Aikotoba::Errors::InvalidScopeConfiguration`, as a blank one does.

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

`Aikotoba::Account` belongs to any model of yours through `authenticate_target`. To create that model together with the account, in the same transaction, write your own sign up controller on the model methods, as shown in [Registrable](#registrable). Sign up only exists in scopes without `authenticate_for` (see [Filtering by authenticate target type](#filtering-by-authenticate-target-type)).

```ruby
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

### Do something before, after, or on failure

Aikotoba's controllers have no methods to override. Pick the tool by what you need:

- **React to something that happened** (log it, send it to an audit trail, alert on it): subscribe to the [Events](#events). They are reported from every caller, so you don't need to touch any controller. A failed sign in is one too (`sign_in_failed`), but a sign in refused by a [rate limit](#rate-limiting) is not.
- **Stop a request before Aikotoba handles it** (block an IP, require a feature flag): add a `before_action` to your `ApplicationController`. Aikotoba's controllers inherit it (`config.parent_controller`), so it runs before them. `is_a?(Aikotoba::ApplicationController)` limits it to Aikotoba's pages, sign in, sign up, magic links and the token pages alike:

  ```ruby
  class ApplicationController < ActionController::Base
    before_action :reject_blocked_ip, if: -> { is_a?(Aikotoba::ApplicationController) }

    private

    def reject_blocked_ip
      head :forbidden if BlockedIp.exists?(address: request.remote_ip)
    end
  end
  ```

  Keep the condition this broad unless you mean one page only: you can sign in with a password or a magic link, and an email address is taken by the sign in page and by every token request, so a check on one action leaves the others open.

- **Change the flow itself, or do more in the same transaction** (create a profile with the account, check the account after its password matched, show your own response to a validation error or to a token request for an email with no account): write your own controller on the model methods Aikotoba's controllers use, such as `Aikotoba::Account.build_by` / `#register!`, `Aikotoba::Account::PasswordHash.authenticate_by` and `aikotoba_sign_in` / `aikotoba_begin_sign_in` / `aikotoba_sign_out`. [Registrable](#registrable) shows a sign up controller. Your controller reports the same events, since the model methods and the sign in helpers report them.

### Events

Aikotoba reports authentication events through Rails' structured event reporter, [`Rails.event`](https://rubyonrails.org/2025/10/22/rails-8-1), so you can track them (audit logs, metrics, alerts) without overriding any controller.

```ruby
# config/initializers/aikotoba_events.rb
class AuthEventSubscriber
  def emit(event)
    AuthEventJob.perform_later(event[:name], event[:payload], event[:context])
  end
end

Rails.event.subscribe(AuthEventSubscriber.new) { |event| event[:name].start_with?("aikotoba.") }
```

| Event                                                                                         | Reported when                                                                   | Payload                                         |
| --------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------- | ----------------------------------------------- |
| `aikotoba.sign_in`                                                                            | a session starts (`aikotoba_sign_in`), with a password or a magic link         | `account_id`, `session_id`, `scope`             |
| `aikotoba.sign_out`                                                                           | a session is revoked (`aikotoba_sign_out`)                                      | `account_id`, `session_id`, `scope`             |
| `aikotoba.sign_in_failed`                                                                     | a password sign in fails (`Aikotoba::Account::PasswordHash.authenticate_by`)    | `email`, `account_id`, `target_type_name`       |
| `aikotoba.magic_link_sign_in_failed`                                                          | a magic link matches no active token (`Aikotoba::Account::MagicLink.authenticate_by`) | `target_type_name`                         |
| `aikotoba.email_otp_sign_in_failed`                                                           | an emailed code is wrong, or none is left to try (`Aikotoba::Account::EmailOtp.authenticate_by`) | `account_id`, `target_type_name` |
| `aikotoba.account_registered`                                                                 | `Aikotoba::Account#register!` saves an account                                  | `account_id`                                    |
| `aikotoba.account_confirmed`                                                                  | an account is confirmed                                                          | `account_id`                                    |
| `aikotoba.account_locked`                                                                     | an account is locked after too many failed sign ins                              | `account_id`                                    |
| `aikotoba.account_unlocked`                                                                   | an account is unlocked                                                           | `account_id`                                    |
| `aikotoba.password_recovered`                                                                 | a password is reset through a recovery token                                     | `account_id`                                    |
| `aikotoba.confirmation_token_issued`, `aikotoba.unlock_token_issued`, `aikotoba.recovery_token_issued`, `aikotoba.magic_link_token_issued`, `aikotoba.email_otp_code_issued` | a token or code is issued, whether or not its email is sent | `account_id`, `notified`                        |

- Each event is also a constant, such as `Aikotoba::Event::SignInFailed`, whose `event_name` is `"aikotoba.sign_in_failed"`, so a subscriber can match on it instead of a string.
- Payloads hold plain values, not records, so a subscriber can serialize them as is. `scope` is the scope's name (`"default"`, `"admin"`). `notified` is whether the token's email was queued: Aikotoba's own pages always send it, but your code may issue a token without (`notify: false`).
- `sign_in_failed`'s `account_id` is `nil` when no account that can sign in to the scope has that email, so you can tell an unknown email from a wrong password. The response to the user is the same either way. It is also `nil` for a blank password, which is rejected before any account is looked up.
- `magic_link_sign_in_failed` is reported for a link that is unknown, expired or already used, or whose account can't sign in to the scope (another target type, or locked or unconfirmed when Lockable or Confirmable is on). Its payload has no token, which is a credential, and no `account_id`, since a failed link doesn't tell whose it was. The user gets a 404 either way.
- `email_otp_sign_in_failed` carries the `account_id`, since the password step already said whose sign in it is, but not the code, which is a credential. A sign in that requires a code reports `sign_in` only once the code is entered, and a wrong password still reports `sign_in_failed`.
- `sign_in_failed`'s `email` is normalized the way Aikotoba looks accounts up (surrounding spaces stripped, lowercased), so `" Victim@Example.com"` and `"victim@example.com"` are reported as the same address. A missing email is reported as `nil`.
- `Rails.event` masks payload keys that match `config.filter_parameters`. New apps filter `:email`, so `sign_in_failed`'s `email` is reported as `"[FILTERED]"` unless you change that filter.
- Request details such as the IP address are not in the payloads, since the models that report them don't see the request. Put them in `Rails.event`'s context, which every event carries and Rails clears between requests:

  ```ruby
  class ApplicationController < ActionController::Base
    before_action { Rails.event.set_context(ip_address: request.remote_ip, user_agent: request.user_agent) }
  end
  ```
- The events are reported from the models and the sign in helpers, not the controllers, so your own controllers built on them report the same events. That includes the console and rake tasks: unlocking an account from the console reports `account_unlocked`.
- Every event except the failed sign ins (`sign_in_failed`, `magic_link_sign_in_failed`, `email_otp_sign_in_failed`) is reported after the database transaction commits, the caller's own included, and not at all if it rolls back, so a subscriber never sees a change that didn't persist. The failed sign ins have nothing to commit, so they are reported right away.
- Subscribers run synchronously, in the request (or job, or console) that reported the event, so keep them fast and enqueue a job for anything slow. `Rails.event` reports an exception raised by a subscriber to `Rails.error` instead of failing the request, except where `config.consider_all_requests_local` is set (development and test by default), where it raises.
- In tests, use Rails' `assert_event_reported("aikotoba.sign_in")` and friends.
- A magic link sign in reports `sign_in` like a password one; its `scope` tells which scope it signed in to.

### Logs

Aikotoba writes a few lines of its own to `Rails.logger`, each prefixed with `[Aikotoba]`, so you can find them among your app's:

- at boot, a warning when an absolute path you set on an added scope is drawn under its `root_path` (see [Filtering by authenticate target type](#filtering-by-authenticate-target-type));
- at the `info` level, when a confirmation, unlock, password reset or magic link email is not sent because no account matches the email. The user sees the same page either way, so this line is how you tell why an email never arrived. It names the scope but not the email, since `config.filter_parameters` doesn't mask a log message.

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

When the default scope has `two_factor_authenticatable`, `aikotoba_sign_in` also enters the code it was sent, so the account ends up signed in either way.

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
