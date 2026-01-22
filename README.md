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

[For more information](#features)

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'aikotoba'
```

## Usage

### Getting Start

Aikotoba use `Aikotoba::Account` for authentication. Add it to the migration for `Aikotoba::Account`.

```sh
$ bin/rails aikotoba:install:migrations
```

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

### Registrable

To enable it, set `Aikotoba.registerable` to `true`. (It is enabled by default.)

```ruby
Aikotoba.registerable = true
```

Register an account using email and password.

| HTTP Verb | Path     | Overview              |
| --------- | -------- | --------------------- |
| GET       | /sign_up | Display sign up page. |
| POST      | /sign_up | Create an account.    |

The password is stored as a hash in [Argon2](https://github.com/technion/ruby-argon2).

### Confirmable

To enable it, set `Aikotoba.confirmable` to `true`.

```ruby
Aikotoba.confirmable = true
```

Aikotoba enable routes for confirmation account. Also, when account registers, a confirmation email is sent to the email address. Only accounts that are confirmed will be authenticated.

| HTTP Verb | Path            | Overview                               |
| --------- | --------------- | -------------------------------------- |
| GET       | /confirm        | Display page for create confirm token. |
| POST      | /confirm        | Create a confirm token to account.     |
| GET       | /confirm/:token | Confirm account by token.              |

### Lockable

To enable it, set `Aikotoba.lockable` to `true`.

```ruby
Aikotoba.lockable = true
```

Aikotoba enables a route to unlock an account. Also, if the authentication fails a certain number of times, the account will be locked. Only accounts that are not locked will be authenticated.

| HTTP Verb | Path           | Overview                              |
| --------- | -------------- | ------------------------------------- |
| GET       | /unlock        | Display page for create unlock token. |
| POST      | /unlock        | Create a unlock token to account.     |
| GET       | /unlock/:token | Unlock account by token.              |

### Recoverable

To enable it, set `Aikotoba.recoverable` to `true`.

```ruby
Aikotoba.recoverable = true
```

Aikotoba enables a route to recover an account by password reset.

| HTTP Verb | Path            | Overview                                            |
| --------- | --------------- | --------------------------------------------------- |
| GET       | /recover        | Display page for create recover token.              |
| POST      | /recover        | Create a recover token to account.                  |
| GET       | /recover/:token | Display page for recover account by password reset. |
| PATCH     | /recover/:token | Recover account by password reset.                  |

### Rate Limiting (Rails 8+ only)

Aikotoba provides built-in rate limiting for email-sending endpoints to prevent email bombing attacks. This feature requires **Rails 8.0 or later**.

Rate limiting is available for:

- **Confirmation token requests** (`/confirm` POST endpoint)
- **Unlock token requests** (`/unlock` POST endpoint)
- **Password recovery token requests** (`/recover` POST endpoint)

By default, rate limiting is disabled (empty configuration). To enable it, configure the respective options:

```ruby
Aikotoba.confirmation_rate_limit_options = {
  to: 10,
  within: 1.hour,
  by: -> { request.params.dig(:account, :email).presence || request.remote_ip },
  only: :create
}
```

When rate limiting is triggered, requests that exceed the limit will receive a 429 (Too Many Requests) response.

For detailed configuration examples and options, see the [Configuration](#configuration) section below.

### Multiple Scopes

Aikotoba supports multiple scopes.

You can add a scope by `Aikotoba.add_scope` method. For example, the following code adds an `admin` scope. Unspecified values will be copied from the `default` scope.

```ruby
Aikotoba.add_scope(:admin, {
  session_key: "aikotoba_admin_session_token",
  root_path: "/admin",
  sign_in_path: "/admin/sign_in",
  sign_up_path: "/admin/sign_up",
  after_sign_in_path: "/admin/sensitives",
  after_sign_out_path: "/admin/sign_in",
  sign_out_path: "/admin/sign_out",
  confirm_path: "/admin/confirm",
  unlock_path: "/admin/unlock",
  recover_path: "/admin/recover"
})
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

aikotoba_scoped_path(:new_session)
#=> "/sign_in" (if current scope is :default)
#=> "/admin/sign_in" (if current scope is :admin)
```

## Configuration

The following configuration parameters are supported. You can override it. (ex. `initializers/aikotoba.rb`)

```ruby
require 'aikotoba'

# ============================================
# Global settings
# ============================================

Aikotoba.parent_controller = "ApplicationController"
Aikotoba.parent_mailer = "ActionMailer::Base"
Aikotoba.mailer_sender = "from@example.com"
Aikotoba.email_format = /\A[^\s]+@[^\s]+\z/
Aikotoba.password_pepper = "aikotoba-default-pepper"
Aikotoba.password_length_range = 8..100
Aikotoba.session_expiry = 7.days


# for registerable
Aikotoba.registerable = true

# for confirmable
Aikotoba.confirmable = false
Aikotoba.confirmation_token_expiry = 1.day

# for lockable
Aikotoba.lockable = false
Aikotoba.max_failed_attempts = 10
Aikotoba.unlock_token_expiry = 1.day

# for Recoverable
Aikotoba.recoverable = false
Aikotoba.recovery_token_expiry = 4.hours

# ============================================
# Rate Limiting (Rails 8+ required)
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
# - Protection against email enumeration attacks
#
# Examples:

# Limit confirmation token requests to 10 per hour, per email address (with IP fallback)
Aikotoba.confirmation_rate_limit_options = {
  to: 10,
  within: 1.hour,
  by: -> { request.params.dig(:account, :email).presence || request.remote_ip },
  only: :create
}

# Limit unlock token requests to 5 per hour, per email address (stricter for security)
Aikotoba.unlock_rate_limit_options = {
  to: 5,
  within: 1.hour,
  by: -> { request.params.dig(:account, :email).presence || request.remote_ip },
  only: :create
}

# Limit recovery token requests to 3 per hour, per email address (most strict for password recovery)
Aikotoba.recovery_rate_limit_options = {
  to: 3,
  within: 1.hour,
  by: -> { request.params.dig(:account, :email).presence || request.remote_ip },
  only: :create
}

# Rate limiting by IP address only (simpler, but less precise)
# Aikotoba.confirmation_rate_limit_options = {
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
Aikotoba.default_scope = {
  authenticate_for: nil,  # No restriction for default scope
  session_key: "aikotoba_session_token",
  root_path: "/",
  sign_in_path: "/sign_in",
  sign_out_path: "/sign_out",
  sign_up_path: "/sign_up",
  confirm_path: "/confirm",
  unlock_path: "/unlock",
  recover_path: "/recover",
  after_sign_in_path: "/sensitives",
  after_sign_out_path: "/sign_in"
}

# for Additional Scopes
Aikotoba.add_scope(:admin, {
  authenticate_for: "Admin",  # Restrict authentication to Admin accounts
  session_key: "aikotoba_admin_session_token",
  root_path: "/admin",
  sign_in_path: "/admin/sign_in",
  sign_out_path: "/admin/sign_out",
  sign_up_path: "/admin/sign_up",
  confirm_path: "/admin/confirm",
  unlock_path: "/admin/unlock",
  recover_path: "/admin/recover",
  after_sign_in_path: "/admin/sensitives",
  after_sign_out_path: "/admin/sign_in"
})
```

### Scope Configuration Details

`Aikotoba.default_scope=` **merges** the provided hash into the existing default scope (does not replace):

```ruby
# Single key update
Aikotoba.default_scope[:sign_in_path] = "/custom"

# Multiple keys update (recommended for bulk changes)
Aikotoba.default_scope = {
  sign_in_path: "/custom_sign_in",
  after_sign_in_path: "/dashboard"
}
# Other keys (root_path, session_key, etc.) remain unchanged
```

Both approaches are valid. Use direct key assignment for single changes, or use `default_scope=` for updating multiple keys at once.

#### Filtering by authenticate target type

You can restrict authentication to specific target types by setting `authenticate_for`:

```ruby
Aikotoba.add_scope(:admin, {
  authenticate_for: "Admin",  # Only Admin accounts can sign in to this scope
  root_path: "/admin",
  sign_in_path: "/admin/sign_in",
  # ...
})
```

When `authenticate_for` is set, only accounts with matching `authenticate_target_type` will authenticate successfully in that scope.
This is useful for separating authentication between different user types (e.g., Admin vs User).

**Note:** The account type is determined by the model associated via `authenticate_target`. Set up your associations in `after_create_account_process`:

```ruby
Rails.application.config.to_prepare do
  Aikotoba::AccountsController.class_eval do
    def after_create_account_process
      if aikotoba_scope.admin?
        admin = Admin.new(nickname: "admin_foo")
        @account.authenticate_target = admin
        admin.save!
      else
        user = User.new(nickname: "foo")
        @account.authenticate_target = user
        user.save!
      end
      @account.save!
    end
  end
end
```

## Tips

### Customize Message

All Messages are managed by `i18n` and can be freely overridden.

### Manually create an `Aikotoba::Account` for authentication.

By running the following script, you can hash and store passwords.

```ruby
Aikotoba::Account.create!(email: "sample@example.com", password: "password")
Aikotoba::Account.authenticate_by(attributes: {email: "sample@example.com", password: "password"})
# => created account instance.
```

### Create other model with `Aikotoba::Account`.

You can override `Aikotoba::AccountsController#after_create_account_process` to create the other models together.

```ruby
require 'aikotoba'

Rails.application.config.to_prepare do
  Aikotoba::AccountsController.class_eval do
    def after_create_account_process
      # You can get the scope name by `aikotoba_scope` method.
      if aikotoba_scope.admin?
        admin = Admin.new(nickname: "admin_foo")
        @account.authenticate_target = admin
        admin.save!
      else
        user = User.new(nickname: "foo")
        @account.authenticate_target = user
        user.save!
      end
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
Aikotoba.encrypted_token = true
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
    email, password = ["email@example.com", "password"]
    @account = ::Aikotoba::Account.build_by(attributes: {email: email, password: password})
    @account.save
  end

  test "sign_in by helper" do
    aikotoba_sign_in(@account)
    visit "/sensitives"
    assert_selector "h1", text: "Sensitive Page"
    click_on "Sign out"
    assert_selector ".message", text: "Signed out."
  end

  test "sign_out by helper" do
    aikotoba_sign_in(@account)
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
