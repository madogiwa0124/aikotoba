# frozen_string_literal: true

require "test_helper"

class Aikotoba::ScopesTest < ActiveSupport::TestCase
  def setup
    @original = Aikotoba.scopes.deep_dup
  end

  def teardown
    Aikotoba.scopes.replace(@original)
  end

  test "every stored scope is a Scope, however it got there" do
    assert_instance_of Aikotoba::Scopes, Aikotoba.scopes
    assert_instance_of Aikotoba::Scope, Aikotoba.default_scope
    assert_instance_of Aikotoba::Scope, Aikotoba.scopes[:admin]

    Aikotoba.add_scope(:added, root_path: "/added")
    assert_instance_of Aikotoba::Scope, Aikotoba.scopes[:added]

    Aikotoba.scopes[:assigned] = {root_path: "/assigned"}
    assert_instance_of Aikotoba::Scope, Aikotoba.scopes[:assigned]
    assert Aikotoba.scopes[:assigned].registerable?
  end

  test "deep_dup / replace / except keep the classes, to_hash gives plain hashes" do
    copy = Aikotoba.scopes.deep_dup
    assert_instance_of Aikotoba::Scopes, copy
    assert_instance_of Aikotoba::Scope, copy[:default]

    Aikotoba.scopes.replace(copy)
    assert_instance_of Aikotoba::Scope, Aikotoba.scopes[:admin]
    assert_instance_of Aikotoba::Scope, Aikotoba.scopes.except(:default)[:admin]

    assert_instance_of Hash, Aikotoba.scopes.to_hash["default"]
  end

  test "documented hash access still works" do
    Aikotoba.default_scope[:sign_in_path] = "/login"
    assert_equal "/login", Aikotoba.scopes[:default][:sign_in_path]
    assert_equal "/login", Aikotoba.scopes["default"]["sign_in_path"]

    Aikotoba.default_scope = {sign_out_path: "/logout"}
    assert_equal "/logout", Aikotoba.default_scope[:sign_out_path]
    assert_equal "/login", Aikotoba.default_scope[:sign_in_path]
  end

  test "Scope#for? matches only a set authenticate_for" do
    assert Aikotoba::Scope.new(authenticate_for: "Admin").for?("Admin")
    assert Aikotoba::Scope.new(authenticate_for: Admin).for?("Admin")
    assert_not Aikotoba::Scope.new(authenticate_for: "Admin").for?("User")
    assert_not Aikotoba::Scope.new(authenticate_for: nil).for?(nil)
    assert_not Aikotoba::Scope.new(authenticate_for: "").for?("")
  end
end
