# frozen_string_literal: true

require "test_helper"
require "minitest/autorun"

class Aikotoba::TokenEncryptableTest < ActiveSupport::TestCase
  def setup
    Aikotoba.config.encrypted_token = true
    reload_confirmation_token_class
    email, password = ["email@example.com", "password"]
    @account = ::Aikotoba::Account.build_by(attributes: {email: email, password: password})
    @account.save
  end

  # NOTE: The class reads encrypted_token when it is loaded, which happens here, before
  #       test_helper restores the configuration, so turn it off first.
  def teardown
    Aikotoba.config.encrypted_token = false
    reload_confirmation_token_class
  end

  test "The token must be encrypted." do
    ::Aikotoba::Account::ConfirmationToken.create(account: @account, token: "generated_token_1")
    found_token = ::Aikotoba::Account::ConfirmationToken.find_by(token: "generated_token_1")
    encrypted_token = "{\"p\":\"4P8OBmTH31wihhJq++M1iuU=\",\"h\":{\"iv\":\"Wox4jyGiHXpaaEXN\",\"at\":\"4FZ5dHQFKGnBJacTK0PttA==\"}}"
    assert_equal found_token.token_before_type_cast, encrypted_token
  end

  test "Being able to find the token by the original value." do
    token = ::Aikotoba::Account::ConfirmationToken.create(account: @account, token: "generated_token_2")
    found_token = ::Aikotoba::Account::ConfirmationToken.find_by(token: "generated_token_2")
    assert_equal found_token, token
    assert_equal found_token.token, "generated_token_2"
  end

  test "Being able to find the token by the original value through a scope-filtered join on the account." do
    admin_account = ::Aikotoba::Account.create_by!(attributes: {email: "encrypted_admin@example.com", password: "password", authenticate_target: Admin.create!(nickname: "encrypted")})
    token = ::Aikotoba::Account::ConfirmationToken.create(account: admin_account, token: "generated_token_3")
    found_token = ::Aikotoba::Account::ConfirmationToken.for_target_type("Admin").find_by(token: "generated_token_3")
    assert_equal token, found_token
    assert_nil ::Aikotoba::Account::ConfirmationToken.for_target_type("User").find_by(token: "generated_token_3")
  end

  private

  # NOTE: If Aikotoba::Account::ConfirmationToken is loaded first while Aikotoba.enypted_token is disabled,
  # the encryption cannot be enabled, so it is reloaded.
  def reload_confirmation_token_class
    Aikotoba::Account.send(:remove_const, :ConfirmationToken)
    load "app/models/aikotoba/account/confirmation_token.rb"
  end
end

class Aikotoba::EmailOtpCodeEncryptionTest < ActiveSupport::TestCase
  def setup
    Aikotoba.config.encrypted_token = true
    reload_email_otp_code_class
    @account = ::Aikotoba::Account.create_by!(attributes: {email: "email_otp_encrypted@example.com", password: "password"})
  end

  # NOTE: See Aikotoba::TokenEncryptableTest#teardown.
  def teardown
    Aikotoba.config.encrypted_token = false
    reload_email_otp_code_class
  end

  test "the code is stored encrypted and still checked against the original value" do
    Aikotoba::Account::EmailOtp.create_code!(account: @account, notify: false)
    code = @account.reload.email_otp_code
    assert_match(/\A\d{6}\z/, code.code)
    assert_not_equal code.code, code.code_before_type_cast
    assert_includes code.code_before_type_cast, "\"p\":"
    assert_equal @account, Aikotoba::Account::EmailOtp.authenticate_by(account_id: @account.id, response: code.code)
  end

  private

  # NOTE: The code is built through Account's has_one, whose reflection keeps the class it
  #       resolved first, so it is pointed at the reloaded class too. Otherwise the tests after
  #       this one would keep building codes with the encrypting class.
  def reload_email_otp_code_class
    Aikotoba::Account.send(:remove_const, :EmailOtpCode)
    load "app/models/aikotoba/account/email_otp_code.rb"
    Aikotoba::Account.reflect_on_association(:email_otp_code).instance_variable_set(:@klass, nil)
  end
end
