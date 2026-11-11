# frozen_string_literal: true

require "test_helper"
require "minitest/mock"

# NOTE: A scope with two_factor_authenticatable: a correct password sends a one-time code by
#       email instead of signing in, and the session starts only once the code is entered.
class Aikotoba::TwoFactorAuthenticatableTest < ActionDispatch::IntegrationTest
  def setup
    ActionController::Base.allow_forgery_protection = false
    Aikotoba.config.default_scope[:two_factor_authenticatable] = true
    @password = "password"
    @account = Aikotoba::Account.create_by!(attributes: {email: "two_factor@example.com", password: @password})
  end

  def sign_in_with_password(path: aikotoba.create_session_path, account: @account)
    post path, params: {account: {email: account.email, password: @password}}
  end

  def submit_code(code, path: aikotoba.create_two_factor_path)
    post path, params: {two_factor: {response: code}}
  end

  def current_code(account = @account)
    account.reload.email_otp_code.code
  end

  def wrong_code(account = @account)
    current_code(account).succ.last(Aikotoba::Account::EmailOtpCode::LENGTH)
  end

  def assert_signed_in
    get aikotoba.new_session_path
    assert_redirected_to Aikotoba.default_scope[:after_sign_in_path]
  end

  def assert_not_signed_in
    get "/sensitives"
    assert_redirected_to aikotoba.new_session_path
  end

  test "a correct password sends a code and does not sign in yet" do
    assert_emails 1 do
      assert_no_difference "Aikotoba::Account::Session.count" do
        sign_in_with_password
      end
    end
    assert_redirected_to aikotoba.new_two_factor_path
    assert_equal I18n.t(".aikotoba.messages.two_factor.required"), flash[:notice]

    mail = ActionMailer::Base.deliveries.last
    assert_equal [@account.email], mail.to
    assert_equal I18n.t(".aikotoba.mailers.email_otp.subject"), mail.subject
    assert_includes mail.body.to_s, current_code
    assert_match(/\A\d{6}\z/, current_code)
    assert_not_signed_in
  end

  test "a wrong password sends no code" do
    assert_no_emails do
      post aikotoba.create_session_path, params: {account: {email: @account.email, password: "wrong"}}
    end
    assert_response :unprocessable_entity
    assert_nil @account.reload.email_otp_code
  end

  test "GET new_two_factor_path shows the code form while a sign in is in progress" do
    sign_in_with_password
    get aikotoba.new_two_factor_path
    assert_response :ok
    assert_select "h1", I18n.t(".aikotoba.two_factors.new")
    assert_select "input[name='two_factor[response]'][autocomplete='one-time-code']"
  end

  test "the correct code signs in, consumes the code and reports sign_in" do
    sign_in_with_password
    code = current_code
    assert_difference "Aikotoba::Account::Session.count", 1 do
      assert_event_reported("aikotoba.sign_in", payload: {account_id: @account.id, scope: "default"}) do
        submit_code(code)
      end
    end
    assert_redirected_to Aikotoba.default_scope[:after_sign_in_path]
    assert_equal I18n.t(".aikotoba.messages.authentication.success"), flash[:notice]
    assert_nil @account.reload.email_otp_code
    assert_signed_in
  end

  test "spaces around and inside the code are ignored" do
    sign_in_with_password
    code = current_code
    submit_code(" #{code[0, 3]} #{code[3..]} ")
    assert_redirected_to Aikotoba.default_scope[:after_sign_in_path]
  end

  test "a wrong code re-renders the form and counts an attempt" do
    sign_in_with_password
    assert_event_reported("aikotoba.email_otp_sign_in_failed", payload: {account_id: @account.id, target_type_name: nil}) do
      submit_code(wrong_code)
    end
    assert_response :unprocessable_entity
    assert_equal I18n.t(".aikotoba.messages.two_factor.failed"), flash[:alert]
    assert_equal 1, @account.reload.email_otp_code.failed_attempts
    assert_equal 1, @account.failed_attempts
    assert_not_signed_in
  end

  test "a blank code counts as a wrong one" do
    sign_in_with_password
    submit_code("")
    assert_response :unprocessable_entity
    assert_equal 1, @account.reload.email_otp_code.failed_attempts
  end

  test "the code is used up after email_otp_max_failed_attempts wrong codes" do
    Aikotoba.config.email_otp_max_failed_attempts = 3
    sign_in_with_password
    code = current_code
    2.times do
      submit_code(wrong_code)
      assert_response :unprocessable_entity
    end
    submit_code(wrong_code)
    assert_redirected_to aikotoba.new_session_path
    assert_equal I18n.t(".aikotoba.messages.two_factor.expired"), flash[:alert]
    assert_nil @account.reload.email_otp_code

    # NOTE: Even the right code no longer works, and the sign in in progress is gone.
    submit_code(code)
    assert_redirected_to aikotoba.new_session_path
    assert_not_signed_in
  end

  test "an expired code sends the user back to sign in without counting an attempt" do
    sign_in_with_password
    code = current_code
    @account.email_otp_code.update!(expired_at: 1.second.ago)
    submit_code(code)
    assert_redirected_to aikotoba.new_session_path
    assert_equal I18n.t(".aikotoba.messages.two_factor.expired"), flash[:alert]
    assert_equal 0, @account.reload.failed_attempts
    assert_not_signed_in
  end

  test "the sign in in progress expires with the code" do
    sign_in_with_password
    code = current_code
    @account.email_otp_code.update!(expired_at: 1.day.from_now)
    travel Aikotoba.email_otp_code_expiry + 1.second do
      submit_code(code)
    end
    assert_redirected_to aikotoba.new_session_path
    assert_not_signed_in
  end

  test "the two factor page sends the user to sign in when no sign in is in progress" do
    get aikotoba.new_two_factor_path
    assert_redirected_to aikotoba.new_session_path
    assert_equal I18n.t(".aikotoba.messages.two_factor.expired"), flash[:alert]

    submit_code("123456")
    assert_redirected_to aikotoba.new_session_path
  end

  test "a sign in in progress whose strategy is no longer registered starts over" do
    sign_in_with_password
    Aikotoba::Account::TwoFactor.stub(:strategy?, false) do
      get aikotoba.new_two_factor_path
    end
    assert_redirected_to aikotoba.new_session_path
    get aikotoba.new_two_factor_path
    assert_redirected_to aikotoba.new_session_path
  end

  test "a signed in account is sent on from the two factor page" do
    sign_in_with_password
    submit_code(current_code)
    get aikotoba.new_two_factor_path
    assert_redirected_to Aikotoba.default_scope[:after_sign_in_path]
  end

  test "the sign in in progress does not outlive the sign in" do
    sign_in_with_password
    submit_code(current_code)
    delete aikotoba.destroy_session_path
    get aikotoba.new_two_factor_path
    assert_redirected_to aikotoba.new_session_path
  end

  test "signing in again replaces the code" do
    codes = [111111, 222222]
    SecureRandom.stub(:random_number, ->(*) { codes.shift }) do
      sign_in_with_password
      sign_in_with_password
    end
    assert_equal 1, Aikotoba::Account::EmailOtpCode.where(aikotoba_account_id: @account.id).count
    submit_code("111111")
    assert_response :unprocessable_entity
    submit_code("222222")
    assert_redirected_to Aikotoba.default_scope[:after_sign_in_path]
  end

  test "sign in goes back to the protected page that sent the account to sign in" do
    get "/sensitives?from=protected"
    sign_in_with_password
    submit_code(current_code)
    assert_redirected_to "/sensitives?from=protected"
  end

  test "a correct password does not reset failed_attempts before the code is entered" do
    @account.update!(failed_attempts: 3)
    sign_in_with_password
    assert_equal 3, @account.reload.failed_attempts
    submit_code(current_code)
    assert_equal 0, @account.reload.failed_attempts
  end

  test "with Lockable, wrong codes lock the account across fresh codes" do
    Aikotoba.config.lockable = true
    Aikotoba.config.max_failed_attempts = 3
    # NOTE: Signing in again with the right password issues a fresh code, but doesn't reset
    #       the count, so someone holding the password can't keep guessing.
    2.times do
      sign_in_with_password
      2.times { submit_code(wrong_code) }
    end
    assert @account.reload.locked?
    assert_nil @account.email_otp_code
    assert_redirected_to aikotoba.new_session_path

    sign_in_with_password
    assert_response :unprocessable_entity
    assert_not_signed_in
  end

  test "an account locked during the sign in can't finish it" do
    Aikotoba.config.lockable = true
    sign_in_with_password
    code = current_code
    @account.lock!
    submit_code(code)
    assert_redirected_to aikotoba.new_session_path
    assert_not_signed_in
  end

  test "magic link sign in does not ask for a code" do
    Aikotoba.config.magic_link_authenticatable = true
    Aikotoba::Account::MagicLink.create_token!(account: @account, notify: false)
    assert_no_emails do
      get aikotoba.authenticate_via_magic_link_path(token: @account.magic_link_token.token)
    end
    assert_redirected_to Aikotoba.default_scope[:after_sign_in_path]
    assert_signed_in
  end

  test "the two factor routes return 404 when the scope does not require it" do
    Aikotoba.config.default_scope[:two_factor_authenticatable] = false
    get aikotoba.new_two_factor_path
    assert_response :not_found
    post aikotoba.create_two_factor_path, params: {two_factor: {response: "123456"}}
    assert_response :not_found
  end

  test "without two_factor_authenticatable a correct password signs in right away" do
    Aikotoba.config.default_scope[:two_factor_authenticatable] = false
    assert_no_emails { sign_in_with_password }
    assert_redirected_to Aikotoba.default_scope[:after_sign_in_path]
    assert_nil @account.reload.email_otp_code
  end

  class AdminScope < ActionDispatch::IntegrationTest
    def setup
      ActionController::Base.allow_forgery_protection = false
      Aikotoba.config.scopes[:admin][:two_factor_authenticatable] = true
      @password = "password"
      @admin_account = Aikotoba::Account.create_by!(attributes: {email: "two_factor_admin@example.com", password: @password, authenticate_target: Admin.create!(nickname: "two_factor")})
      @user_account = Aikotoba::Account.create_by!(attributes: {email: "two_factor_user@example.com", password: @password})
    end

    test "only the scope that turns it on asks for a code" do
      post aikotoba.create_session_path, params: {account: {email: @user_account.email, password: @password}}
      assert_redirected_to Aikotoba.default_scope[:after_sign_in_path]
      get aikotoba.new_two_factor_path
      assert_response :not_found

      post aikotoba.admin_create_session_path, params: {account: {email: @admin_account.email, password: @password}}
      assert_redirected_to "/admin/two_factor"
    end

    test "the admin scope signs in with its own code" do
      post aikotoba.admin_create_session_path, params: {account: {email: @admin_account.email, password: @password}}
      post aikotoba.admin_create_two_factor_path, params: {two_factor: {response: @admin_account.reload.email_otp_code.code}}
      assert_redirected_to Aikotoba.scopes[:admin][:after_sign_in_path]
      get "/admin/sensitives"
      assert_response :ok
    end

    test "a sign in in progress for one scope can't be finished in another" do
      post aikotoba.admin_create_session_path, params: {account: {email: @admin_account.email, password: @password}}
      Aikotoba.config.default_scope[:two_factor_authenticatable] = true
      post aikotoba.create_two_factor_path, params: {two_factor: {response: @admin_account.reload.email_otp_code.code}}
      assert_redirected_to aikotoba.new_session_path
      assert_not_nil @admin_account.reload.email_otp_code
    end
  end
end

class Aikotoba::TwoFactorRequestHelperTest < ActionDispatch::IntegrationTest
  include Aikotoba::Test::AuthenticationHelper::Request

  test "aikotoba_sign_in enters the code when the default scope requires it" do
    ActionController::Base.allow_forgery_protection = false
    Aikotoba.config.default_scope[:two_factor_authenticatable] = true
    account = Aikotoba::Account.create_by!(attributes: {email: "request_helper@example.com", password: "password"})
    aikotoba_sign_in(account, password: "password")
    assert_equal Aikotoba.default_scope[:after_sign_in_path], path
    get "/sensitives"
    assert_response :ok
  end
end
