require "test_helper"

class AikotobaTest < ActiveSupport::TestCase
  test "it has a version number" do
    assert Aikotoba::VERSION
  end

  def with_captured_deprecations(deprecator = Aikotoba::DEPRECATOR)
    original_behavior = deprecator.behavior
    captured = []
    deprecator.behavior = [proc { |msg, _callstack, _deprecator| captured << msg }]
    yield captured
  ensure
    deprecator.behavior = original_behavior
  end

  test "default_scope= merges into default_scope" do
    original = Aikotoba.scopes.deep_dup
    begin
      assert_equal "/sign_in", Aikotoba.default_scope[:sign_in_path]

      Aikotoba.default_scope = {sign_in_path: "/custom_sign_in"}

      assert_equal "/custom_sign_in", Aikotoba.default_scope[:sign_in_path]
    ensure
      Aikotoba.scopes.replace(original)
    end
  end

  test "add_scope merges defaults with overrides" do
    original = Aikotoba.scopes.deep_dup
    begin
      Aikotoba.add_scope(:admin, root_path: "/admin", sign_in_path: "/admin/sign_in")

      admin = Aikotoba.scopes[:admin]
      assert_equal "/admin", admin[:root_path]
      assert_equal "/admin/sign_in", admin[:sign_in_path]
      # Inherit unspecified keys from default
      assert_equal Aikotoba.default_scope[:sign_out_path], admin[:sign_out_path]
    ensure
      Aikotoba.scopes.replace(original)
    end
  end

  test "legacy getter emits deprecation warning" do
    with_captured_deprecations do |captured|
      original = Aikotoba.scopes.deep_dup

      begin
        assert_equal Aikotoba.sign_in_path, Aikotoba.default_scope[:sign_in_path]
        Aikotoba.default_scope[:sign_in_path] = "/another_path"
        assert_equal Aikotoba.sign_in_path, "/another_path"

        assert captured.any? { |m| m.include?("Aikotoba.sign_in_path is deprecated") },
          "expected deprecation warning for legacy getter"
      ensure
        Aikotoba.scopes.replace(original)
      end
    end
  end

  test "legacy setter emits deprecation and updates default_scope" do
    original = Aikotoba.scopes.deep_dup
    begin
      with_captured_deprecations do |captured|
        Aikotoba.sign_in_path = "/via_legacy_setter"
        assert captured.any? { |m| m.include?("Aikotoba.sign_in_path= is deprecated") },
          "expected deprecation warning for legacy setter"
      end

      assert_equal "/via_legacy_setter", Aikotoba.default_scope[:sign_in_path]
    ensure
      Aikotoba.scopes.replace(original)
    end
  end

  test "default_scope contains all expected keys" do
    expected_keys = %i[
      root_path authenticate_for session_key sign_in_path sign_out_path
      after_sign_in_path after_sign_out_path sign_up_path
      confirm_path unlock_path recover_path api_sign_in_path api_refresh_path api_sign_out_path
    ]
    expected_keys.each do |key|
      assert Aikotoba.default_scope.key?(key), "Missing key: #{key}"
    end
  end
end
