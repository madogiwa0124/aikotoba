require "test_helper"

class AikotobaTest < ActiveSupport::TestCase
  test "it has a version number" do
    assert Aikotoba::VERSION
  end

  test "scope_name_for picks the scope whose authenticate_for matches, else default" do
    assert_equal "admin", Aikotoba.scope_name_for("Admin")
    assert_equal "default", Aikotoba.scope_name_for(nil)
    assert_equal "default", Aikotoba.scope_name_for("User")
  end

  test "a scope with a blank authenticate_for is unrestricted everywhere" do
    assert Aikotoba.registerable_scope?({authenticate_for: ""})
    assert Aikotoba.registerable_scope?({authenticate_for: nil})
    assert_not Aikotoba.registerable_scope?({authenticate_for: "Admin"})

    original = Aikotoba.scopes.deep_dup
    begin
      Aikotoba.add_scope(:blank, authenticate_for: "")
      assert_equal "default", Aikotoba.scope_name_for("")
      assert_equal "default", Aikotoba.scope_name_for(nil)
      assert_equal "admin", Aikotoba.scope_name_for("Admin")
    ensure
      Aikotoba.scopes.replace(original)
    end
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
