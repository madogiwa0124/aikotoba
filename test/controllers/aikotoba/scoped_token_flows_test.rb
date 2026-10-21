# frozen_string_literal: true

require "test_helper"

# Each scope's token endpoints only handle the accounts that can sign in to that scope,
# and emails link to the scope the account belongs to.
class Aikotoba::ScopedTokenFlowsTest < ActionDispatch::IntegrationTest
  def setup
    ActionController::Base.allow_forgery_protection = false
    Aikotoba.confirmable = true
    Aikotoba.lockable = true
    Aikotoba.recoverable = true
    Aikotoba.magic_link_authenticatable = true
    @user_account = Aikotoba::Account.create_by!(attributes: {email: "scoped_user@example.com", password: "password"})
    @admin_account = Aikotoba::Account.create_by!(attributes: {email: "scoped_admin@example.com", password: "password", authenticate_target: Admin.create!(nickname: "scoped")})
  end

  def teardown
    Aikotoba.confirmable = false
    Aikotoba.lockable = false
    Aikotoba.recoverable = false
    Aikotoba.magic_link_authenticatable = false
  end

  {
    confirm: "/admin/confirm",
    unlock: "/admin/unlock",
    recover: "/admin/recover",
    magic_link: "/admin/magic_link"
  }.each do |feature, admin_path|
    test "#{feature}: admin scope does not send to an account outside its authenticate_for" do
      @user_account.lock! if feature == :unlock
      assert_no_emails do
        post admin_path, params: {account: {email: @user_account.email}}
      end
    end

    test "#{feature}: admin scope sends to its own account, linking to the admin scope" do
      @admin_account.lock! if feature == :unlock
      assert_emails 1 do
        post admin_path, params: {account: {email: @admin_account.email}}
      end
      assert_match %r{#{admin_path}/\S+}, ActionMailer::Base.deliveries.last.body.to_s
    end
  end

  test "default scope still sends to an Admin account, linking to the admin scope" do
    assert_emails 1 do
      post "/recover", params: {account: {email: @admin_account.email}}
    end
    assert_includes ActionMailer::Base.deliveries.last.body.to_s, "/admin/recover/#{@admin_account.reload.recovery_token.token}"
  end

  test "an account outside the scope's authenticate_for gets 404 for its token" do
    Aikotoba::Account::Confirmation.create_token!(account: @user_account)
    get "/admin/confirm/#{@user_account.confirmation_token.token}"
    assert_equal 404, status
    assert_not @user_account.reload.confirmed?

    @user_account.lock!
    Aikotoba::Account::Lock.create_unlock_token!(account: @user_account)
    get "/admin/unlock/#{@user_account.unlock_token.token}"
    assert_equal 404, status
    assert @user_account.reload.locked?

    Aikotoba::Account::Recovery.create_token!(account: @user_account)
    get "/admin/recover/#{@user_account.recovery_token.token}"
    assert_equal 404, status
    patch "/admin/recover/#{@user_account.recovery_token.token}", params: {account: {password: "new_password"}}
    assert_equal 404, status

    Aikotoba::Account::MagicLink.create_token!(account: @user_account)
    get "/admin/magic_link/#{@user_account.magic_link_token.token}"
    assert_equal 404, status
  end

  test "an account inside the scope's authenticate_for can use its token there" do
    Aikotoba::Account::Confirmation.create_token!(account: @admin_account)
    get "/admin/confirm/#{@admin_account.confirmation_token.token}"
    assert_redirected_to "/admin/sign_in"
    assert @admin_account.reload.confirmed?
  end
end
