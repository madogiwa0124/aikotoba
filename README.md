[![CI](https://github.com/madogiwa0124/aikotoba/actions/workflows/ci.yml/badge.svg)](https://github.com/madogiwa0124/aikotoba/actions/workflows/ci.yml)

# Aikotoba

Aikotoba meaning password in Japanese.

Aikotoba is a Rails engine that makes it easy to implement simple email and password authentication.

**Motivation**

- Simple implementation using the Rails engine.
- Modern hashing algorithm.
- Separate the authentication logic from User.
- Implementation for multiple DB.

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
  include Aikotoba::Authenticatable # enabled authenticatable methods (ex. `current_user`)

  # NOTE: You can also implement the authorization process as follows
  def authenticate_user!
    return if current_user
    redirect_to aikotoba.new_session_path, flash: {alert: "Oops. You need to Signed up or Signed in." }
  end
end
```

Aikotoba enable helper methods for authentication(ex. `current_user`).

```ruby
class SensitiveController < ApplicationController
  before_action :authenticate_user!

  def index
    @records = current_user.sensitive_records
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

Aikotoba enable helper methods for authentication. The method name can be changed by configuration.

- `current_user` : Returns the logged in instance of `Aikotoba::Account`.

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

## Configuration

The following configuration parameters are supported. You can override it. (ex. `initializers/aikotoba.rb`)

```ruby
require 'aikotoba'

Aikotoba.authenticate_account_method = "current_user"
Aikotoba.email_format = /\A[^\s]+@[^\s]+\z/
Aikotoba.prevent_timing_atack = true
Aikotoba.password_pepper = "aikotoba-default-pepper"
Aikotoba.password_format = /.{8,72}+\z/
Aikotoba.sign_in_path = "/sign_in"
Aikotoba.sign_out_path = "/sign_out"
Aikotoba.after_sign_in_path = "/"
Aikotoba.after_sign_out_path = "/sign_in"

# for registerable
Aikotoba.registerable = true
Aikotoba.sign_up_path = "/sign_up"

# for confirmable
Aikotoba.confirmable = false
Aikotoba.confirm_path = "/confirm"
Aikotoba.confirmation_token_expiry = 5.days

# for lockable
Aikotoba.lockable = false
Aikotoba.unlock_path = "/unlock"
Aikotoba.max_failed_attempts = 10
Aikotoba.unlock_token_expiry = 5.days

# for Recoverable
Aikotoba.recoverable = false
Aikotoba.recover_path = "/unlock"
Aikotoba.recovery_token_expiry = 5.days
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
      profile = Profile.new(nickname: "foo")
      profile.save!
      @account.update!(authenticate_target: profile)
    end
  end
end

class Profile < ApplicationRecord
  has_one :user, class_name: 'Aikotoba::Account'
end

current_user.profile #=> Profile instance
profile.user #=> Aikotoba::Account instance
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
