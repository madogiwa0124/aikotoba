[![CI](https://github.com/madogiwa0124/aikotoba/actions/workflows/ci.yml/badge.svg)](https://github.com/madogiwa0124/aikotoba/actions/workflows/ci.yml)

# Aikotoba

Aikotoba meaning password in Japanese.

Aikotoba is a Rails engine that makes it easy to implement simple email and password authentication.

**Motivation**

- Simple implementation using the Rails engine.
- Modern hashing algorithm.
- Separate the authentication logic from User.

**Features**

- Registrable : Register an account using your email address and password.
- Authenticatable : Authenticate account using email and password.
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

include `Aikotoba::Authorizable` and `Aikotoba::Authenticatable` to the controller(ex. `ApplicationController`) use authentication.

```ruby
class ApplicationController < ActionController::Base
  include Aikotoba::Authorizable # enabled authorizable methods (ex. `authenticate_user!`)
  include Aikotoba::Authenticatable # enabled authenticatable methods (ex. `current_user`)
end
```

Aikotoba enable helper methods for authentication(ex. `authenticate_user!`, `current_user`).

```ruby
class SensitiveController < ApplicationController
  before_action :authenticate_user!

  def index
    @records = current_user.sensitive_records
  end
end
```

## Features

### Registrable

Register an account using email and password. The password is stored as a hash in [Argon2](https://github.com/technion/ruby-argon2).

| HTTP Verb | Path     | Overview              |
| --------- | -------- | --------------------- |
| GET       | /sign_up | Display sign up page. |
| POST      | /sign_up | Create an account.    |

### Authenticatable

Authenticate an account using email and password.

| HTTP Verb | Path      | Overview                                  |
| --------- | --------- | ----------------------------------------- |
| GET       | /sign_in  | Display sign in page.                     |
| POST      | /sign_in  | Create a login session by authenticating. |
| DELETE    | /sign_out | Clear aikotoba login session.             |

Aikotoba enable helper methods for authentication. The method name can be changed by configuration.

- `authenticate_user!` : Redirects to the specified path if the user is not logged in. The redirect path can be changed by configuration.
- `current_user` : Returns the logged in instance of `Aikotoba::Account`.

### Confirmable

To enable it, set `Aikotoba.enable_confirm` to `true`.

```ruby
Aikotoba.enable_confirm = true
```

Aikotoba enable routes for confirmation account. Also, when account registers, a confirmation email is sent to the email address. Only accounts that are confirmed will be authenticated.

| HTTP Verb | Path            | Overview                               |
| --------- | --------------- | -------------------------------------- |
| GET       | /confirm        | Display page for create confirm token. |
| POST      | /confirm        | Create a confirm token to account.     |
| GET       | /confirm/:token | Confirm account by token.              |

### Lockable

To enable it, set `Aikotoba.enable_lock` to `true`.

```ruby
Aikotoba.enable_lock = true
```

Aikotoba enables a route to unlock an account. Also, if the authentication fails a certain number of times, the account will be locked. Only accounts that are not locked will be authenticated.

| HTTP Verb | Path           | Overview                              |
| --------- | -------------- | ------------------------------------- |
| GET       | /unlock        | Display page for create unlock token. |
| POST      | /unlock        | Create a unlock token to account.     |
| GET       | /unlock/:token | Unlock account by token.              |

### Recoverable

To enable it, set `Aikotoba.enable_recover` to `true`.

```ruby
Aikotoba.enable_recover = true
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
Aikotoba.authorize_account_method = "authenticate_user!"
Aikotoba.prevent_timing_atack = true
Aikotoba.password_pepper = "aikotoba-default-pepper"
Aikotoba.password_stretch = 3
Aikotoba.password_minimum_length = 10
Aikotoba.sign_in_path = "/sign_in"
Aikotoba.sign_up_path = "/sign_up"
Aikotoba.sign_out_path = "/sign_out"
Aikotoba.after_sign_in_path = "/"
Aikotoba.failed_sign_in_path = "/sign_in"
Aikotoba.after_sign_up_path = "/sign_in"
Aikotoba.after_sign_out_path = "/sign_in"
Aikotoba.appeal_sign_in_path = "/sign_in"

# for confirmable
Aikotoba.enable_confirm = false
Aikotoba.confirm_path = "/confirm"

# for lockable
Aikotoba.enable_lock = false
Aikotoba.unlock_path = "/unlock"
Aikotoba.max_failed_attempts = 10

# for Recoverable
Aikotoba.enable_recover = false
Aikotoba.recover_path = "/unlock"
```

## Tips

### Customize Message

All Messages are managed by `i18n` and can be freely overridden.

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
    @account = ::Aikotoba::Account.build_account_by(attributes: {email: email, password: password})
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
