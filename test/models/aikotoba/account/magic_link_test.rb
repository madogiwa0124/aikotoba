# frozen_string_literal: true

require "test_helper"

class Aikotoba::Account::MagicLinkTest < ActiveSupport::TestCase
  class AuthenticateBy < ActiveSupport::TestCase
    def setup
      @account = Aikotoba::Account.create!(email: "user@example.com", confirmed: true, locked: false)
      @account.build_magic_link_token.save!
    end

    test "account has no password" do
      assert_nil @account.password_hash
    end

    test "authenticate_by returns account for valid token" do
      account = Aikotoba::Account::MagicLink.authenticate_by(token: @account.magic_link_token.token)
      assert_equal account, @account
    end

    test "authenticate_by returns nil for unknown token" do
      account = Aikotoba::Account::MagicLink.authenticate_by(token: "not_a_real_token")
      assert_nil account
    end

    test "authenticate_by returns nil for expired token" do
      @account.magic_link_token.update!(expired_at: 1.hour.ago)
      account = Aikotoba::Account::MagicLink.authenticate_by(token: @account.magic_link_token.token)
      assert_nil account
    end

    test "authenticate_by consumes the token" do
      token = @account.magic_link_token.token
      Aikotoba::Account::MagicLink.authenticate_by(token: token)
      assert_nil @account.reload.magic_link_token
    end

    test "authenticate_by resets failed_attempts" do
      token = @account.magic_link_token.token
      @account.update!(failed_attempts: 5)
      Aikotoba::Account::MagicLink.authenticate_by(token: token)
      assert_equal @account.reload.failed_attempts, 0
    end

    test "authenticate_by filters by target_type_name" do
      admin = Admin.create!(nickname: "admin_foo")
      admin_account = Aikotoba::Account.create!(email: "admin@example.com", authenticate_target: admin, confirmed: true)
      admin_account.build_magic_link_token.save!

      account = Aikotoba::Account::MagicLink.authenticate_by(token: admin_account.magic_link_token.token, target_type_name: "Admin")
      assert_equal account, admin_account

      account = Aikotoba::Account::MagicLink.authenticate_by(token: @account.magic_link_token.token, target_type_name: "Admin")
      assert_nil account
    end
  end

  class CreateToken < ActiveSupport::TestCase
    test "create_token! builds a token for the account" do
      account = Aikotoba::Account.create!(email: "user@example.com")
      assert_difference "Aikotoba::Account::MagicLinkToken.count", 1 do
        Aikotoba::Account::MagicLink.create_token!(account: account)
      end
    end
  end
end
