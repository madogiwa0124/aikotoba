# frozen_string_literal: true

require "test_helper"
require "minitest/mock"

class Aikotoba::Account::TwoFactor::TotpTest < ActiveSupport::TestCase
  def setup
    @account = Aikotoba::Account.create_by!(attributes: {email: "totp@example.com", password: "password"})
    @totp = Aikotoba::Account::TwoFactor::Totp.new(account: @account)
  end

  def code_at(credential, time)
    ROTP::TOTP.new(credential.secret).at(time)
  end

  # NOTE: Confirmed with the previous step's code, so the current one is still unused.
  def set_up!
    credential = @totp.enroll!
    assert @totp.enable!(code_at(credential, Time.current - 30))
    credential.reload
  end

  test "enroll! creates a pending secret, keeps it while pending, and returns nil once set up" do
    credential = @totp.enroll!
    assert credential.persisted?
    assert_not credential.enabled?
    assert_match(/\A[A-Z2-7]{32}\z/, credential.secret)
    assert_equal credential, @totp.enroll!
    assert_not @totp.usable?

    @totp.enable!(code_at(credential, Time.current))
    assert_nil @totp.enroll!
    assert @totp.usable?
  end

  # NOTE: As if another request created the secret after this one looked for it. The has_one
  #       builder would destroy that row and swap in a new secret; a direct insert fails instead.
  test "enroll! racing another request fails rather than replacing the secret it is showing" do
    created = @totp.enroll!
    @totp.stub(:credential, nil) do
      assert_raises(ActiveRecord::RecordNotUnique) { @totp.enroll! }
    end
    assert_equal [created.secret], Aikotoba::Account::TwoFactor::TotpCredential.where(aikotoba_account_id: @account.id).pluck(:secret)
  end

  test "the account's totp_credential follows enroll! and force_disable!, so destroying it cleans up" do
    assert_nil @account.totp_credential
    created = @totp.enroll!
    assert_equal created, @account.totp_credential

    assert @totp.force_disable!
    assert_nil @account.totp_credential

    @totp.enroll!
    assert_nothing_raised { @account.destroy! }
    assert_equal 0, Aikotoba::Account::TwoFactor::TotpCredential.where(aikotoba_account_id: @account.id).count
  end

  test "enable! turns TOTP on with a code from the app, and reports totp_enabled" do
    credential = @totp.enroll!
    assert_event_reported("aikotoba.totp_enabled", payload: {account_id: @account.id}) do
      assert @totp.enable!(" #{code_at(credential, Time.current)} ")
    end
    credential.reload
    assert credential.enabled?
    assert_not_nil credential.last_otp_at
  end

  test "a wrong code doesn't enable it, and isn't a failed sign in" do
    credential = @totp.enroll!
    assert_not @totp.enable!(code_at(credential, Time.current + 300))
    assert_not credential.reload.enabled?
    assert_equal 0, @account.reload.failed_attempts
  end

  test "enable! without a pending secret, or once set up, does nothing" do
    assert_not @totp.enable!("123456")
    credential = set_up!
    assert_not @totp.enable!(code_at(credential, Time.current))
  end

  test "authenticate accepts the current code once, and leaves failed_attempts for the session to reset" do
    credential = set_up!
    @account.update!(failed_attempts: 2)
    code = code_at(credential, Time.current)
    assert_equal true, @totp.authenticate(code)
    assert_equal 2, @account.reload.failed_attempts

    assert_equal false, @totp.authenticate(code), "a code is accepted once"
  end

  test "authenticate allows one step of drift each way, and no more" do
    credential = set_up!
    freeze_time do
      assert_equal true, @totp.authenticate(code_at(credential, Time.current + 30))
    end
    credential = set_up_again!
    freeze_time do
      assert_equal false, @totp.authenticate(code_at(credential, Time.current - 60))
      assert_equal false, @totp.authenticate(code_at(credential, Time.current + 60))
    end
  end

  test "a wrong code is a failed sign in, reported as totp_sign_in_failed" do
    set_up!
    assert_event_reported("aikotoba.totp_sign_in_failed", payload: {account_id: @account.id, target_type_name: nil}) do
      assert_equal false, @totp.authenticate("not a code")
    end
    assert_equal 1, @account.reload.failed_attempts
  end

  test "wrong codes lock the account with Lockable" do
    Aikotoba.config.lockable = true
    Aikotoba.config.max_failed_attempts = 1
    set_up!
    @totp.authenticate("not a code")
    assert_not @account.reload.locked?
    assert_event_reported("aikotoba.account_locked", payload: {account_id: @account.id}) do
      @totp.authenticate("not a code")
    end
    assert @account.reload.locked?
  end

  test "authenticate without TOTP set up fails without counting" do
    credential = @totp.enroll!
    assert_equal false, @totp.authenticate(code_at(credential, Time.current))
    assert_equal 0, @account.reload.failed_attempts
    assert_not @totp.challenge_active?
  end

  test "disable_with! needs a current code, and a wrong one counts as a failed sign in" do
    credential = set_up!
    assert_not @totp.disable_with!("not a code")
    assert_equal 1, @account.reload.failed_attempts
    assert @totp.usable?

    assert_event_reported("aikotoba.totp_disabled", payload: {account_id: @account.id}) do
      assert @totp.disable_with!(code_at(credential, Time.current))
    end
    assert_not @totp.usable?
    assert_nil @totp.credential
  end

  test "force_disable! removes TOTP without a code, and says whether there was any" do
    assert_not @totp.force_disable!
    set_up!
    assert_event_reported("aikotoba.totp_disabled") { assert @totp.force_disable! }
    assert_nil @totp.credential

    @totp.enroll!
    assert_no_event_reported("aikotoba.totp_disabled") { assert @totp.force_disable! }
  end

  test "provisioning_uri names the issuer and the account" do
    Aikotoba.config.totp_issuer = "Example Service"
    uri = @totp.enroll!.provisioning_uri
    assert_match %r{\Aotpauth://totp/Example%20Service:totp%40example.com\?secret=[A-Z2-7]+&issuer=Example%20Service\z}, uri
  end

  test "provisioning_qr_code_svg is an inline SVG of the provisioning URI" do
    svg = @totp.enroll!.provisioning_qr_code_svg
    assert_match(/\A<svg[^>]*xmlns="http:\/\/www.w3.org\/2000\/svg"/, svg)
    assert_not_includes svg, "<?xml"
    # NOTE: A white background with the 4-module quiet zone around the code (offset 16 at
    #       module size 4), so it scans on a dark page too; the page sets the size.
    assert_includes svg, 'fill="#fff"'
    assert_includes svg, "translate(16,16)"
    assert_no_match(/<svg[^>]* width=/, svg)
    assert_not svg.html_safe?
  end

  # NOTE: Like Account::PasswordHash's algorithm_class:, the gems are reached through classes
  #       that can be swapped per call.
  test "provisioning_qr_code_svg takes another QR code class, and the URI another algorithm class" do
    qr_code_class = Struct.new(:data) { def svg = "<svg>#{data}</svg>" }
    algorithm_class = Struct.new(:secret, :issuer) { def provisioning_uri(name) = "uri:#{name}" }
    credential = @totp.enroll!
    assert_equal "<svg>#{credential.provisioning_uri}</svg>", credential.provisioning_qr_code_svg(qr_code_class: qr_code_class)
    assert_equal "<svg>uri:totp@example.com</svg>", credential.provisioning_qr_code_svg(algorithm_class: algorithm_class, qr_code_class: qr_code_class)
  end

  test "the issuer falls back to the app's name" do
    assert_includes @totp.enroll!.provisioning_uri, "issuer=Dummy"
  end

  private

  def set_up_again!
    @totp.force_disable!
    set_up!
  end
end
