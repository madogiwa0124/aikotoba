require "test_helper"

class AikotobaTest < ActiveSupport::TestCase
  test "it has a version number" do
    assert Aikotoba::VERSION
  end

  test "scopes.name_for picks the scope whose authenticate_for matches, else default" do
    assert_equal "admin", Aikotoba.scopes.name_for("Admin")
    assert_equal "default", Aikotoba.scopes.name_for(nil)
    assert_equal "default", Aikotoba.scopes.name_for("User")
  end

  test "a scope with a blank authenticate_for is unrestricted everywhere" do
    assert Aikotoba::Scope.new(authenticate_for: "").registerable?
    assert Aikotoba::Scope.new(authenticate_for: nil).registerable?
    assert_not Aikotoba::Scope.new(authenticate_for: "Admin").registerable?

    Aikotoba.config.add_scope(:blank, root_path: "/blank", authenticate_for: "")
    assert_equal "default", Aikotoba.scopes.name_for("")
    assert_equal "default", Aikotoba.scopes.name_for(nil)
    assert_equal "admin", Aikotoba.scopes.name_for("Admin")
  end

  test "add_scope rejects an authenticate_for another scope already has" do
    error = assert_raises(Aikotoba::Errors::InvalidScopeConfiguration) do
      Aikotoba.config.add_scope(:staff, authenticate_for: "Admin", root_path: "/staff")
    end
    assert_match "Admin (admin, staff)", error.message
    assert_not Aikotoba.scopes.key?(:staff)

    Aikotoba.config.add_scope(:public, root_path: "/public")
    assert_nil Aikotoba.scopes[:public][:authenticate_for]
  end

  test "add_scope rejects inheriting the default scope's authenticate_for" do
    Aikotoba.default_scope[:authenticate_for] = "User"
    assert_raises(Aikotoba::Errors::InvalidScopeConfiguration) do
      Aikotoba.config.add_scope(:mobile, root_path: "/mobile")
    end
    Aikotoba.config.add_scope(:mobile, root_path: "/mobile", authenticate_for: nil)
    assert_nil Aikotoba.scopes[:mobile][:authenticate_for]
  end

  test "add_scope rejects a root_path of \"/\", set or inherited" do
    error = assert_raises(Aikotoba::Errors::InvalidScopeConfiguration) do
      Aikotoba.config.add_scope(:staff, authenticate_for: "Staff")
    end
    assert_match %(on: staff ("/")), error.message
    assert_raises(Aikotoba::Errors::InvalidScopeConfiguration) do
      Aikotoba.config.add_scope(:staff, authenticate_for: "Staff", root_path: "/")
    end
    assert_not Aikotoba.scopes.key?(:staff)

    Aikotoba.scopes[:admin][:root_path] = "/"
    assert_raises(Aikotoba::Errors::InvalidScopeConfiguration) { Aikotoba.scopes.validate! }
  end

  test "scopes.validate! catches a duplicate made after add_scope" do
    Aikotoba.scopes.validate!
    Aikotoba.config.default_scope = {authenticate_for: "Admin"}
    assert_raises(Aikotoba::Errors::InvalidScopeConfiguration) { Aikotoba.scopes.validate! }
  end

  test "default_scope= merges into default_scope" do
    assert_equal "/sign_in", Aikotoba.default_scope[:sign_in_path]

    Aikotoba.config.default_scope = {sign_in_path: "/custom_sign_in"}

    assert_equal "/custom_sign_in", Aikotoba.default_scope[:sign_in_path]
  end

  test "add_scope merges defaults with overrides" do
    Aikotoba.config.add_scope(:admin, root_path: "/admin", sign_in_path: "/admin/sign_in")

    admin = Aikotoba.scopes[:admin]
    assert_equal "/admin", admin[:root_path]
    assert_equal "/admin/sign_in", admin[:sign_in_path]
    # Inherit unspecified keys from default
    assert_equal Aikotoba.default_scope[:sign_out_path], admin[:sign_out_path]
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
