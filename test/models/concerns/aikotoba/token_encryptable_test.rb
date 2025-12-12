# frozen_string_literal: true

require "test_helper"
require "minitest/autorun"

class Aikotoba::TokenEncryptableTest < ActiveSupport::TestCase
  include Aikotoba::TokenEncryptable::ClassMethods

  def setup
    Aikotoba.encrypted_token = true
    skip unless available_active_record_encryption?
    reload_confirmation_token_class
    email, password = ["email@example.com", "password"]
    @account = ::Aikotoba::Account.build_by(attributes: {email: email, password: password})
    @account.save
  end

  def teardown
    Aikotoba.encrypted_token = false
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

  private

  # NOTE: If Aikotoba::Account::ConfirmationToken is loaded first while Aikotoba.enypted_token is disabled,
  # the encryption cannot be enabled, so it is reloaded.
  def reload_confirmation_token_class
    Aikotoba::Account.send(:remove_const, :ConfirmationToken)
    load "app/models/aikotoba/account/confirmation_token.rb"
  end
end
