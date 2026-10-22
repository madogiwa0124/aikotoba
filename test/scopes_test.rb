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

  test "Scope#covers? matches the root_path and paths under it only" do
    scope = Aikotoba::Scope.new(root_path: "/admin")
    assert scope.covers?("/admin")
    assert scope.covers?("/admin/sign_in")
    assert_not scope.covers?("/administrator")
    assert_not scope.covers?("/magic_link")
  end

  test "Scope#valid_root_path? accepts an absolute path with segments only" do
    ["/admin", "/admin/", "/a/b"].each do |root_path|
      assert Aikotoba::Scope.new(root_path: root_path).valid_root_path?, root_path
    end
    ["/", "", nil, "//", "admin", "/admin//", " ", "/ad min"].each do |root_path|
      assert_not Aikotoba::Scope.new(root_path: root_path).valid_root_path?, root_path.inspect
    end
  end

  test "Scope#route_path keeps a path under root_path and prefixes any other" do
    scope = Aikotoba::Scope.new(root_path: "/admin", sign_in_path: "/admin/sign_in", magic_link_path: "/magic_link", recover_path: "recover")
    assert_equal "/admin/sign_in", scope.route_path(:sign_in_path)
    assert_equal "/admin/magic_link", scope.route_path(:magic_link_path)
    assert_equal "/admin/recover", scope.route_path(:recover_path)
  end

  test "Scope#covers? and #route_path ignore a trailing slash on root_path" do
    scope = Aikotoba::Scope.new(root_path: "/admin/", sign_in_path: "/admin/sign_in", magic_link_path: "/magic_link")
    assert scope.covers?("/admin")
    assert scope.covers?("/admin/sign_in")
    assert_equal "/admin/sign_in", scope.route_path(:sign_in_path)
    assert_equal "/admin/magic_link", scope.route_path(:magic_link_path)
  end

  test "Scope#route_path_keys leaves out root_path and redirect targets" do
    keys = Aikotoba.default_scope.route_path_keys
    assert_includes keys, "sign_in_path"
    assert_includes keys, "magic_link_path"
    assert_empty keys & %w[root_path after_sign_in_path after_sign_out_path]
  end

  test "warn_rewritten_paths warns about an explicit absolute path outside root_path, and only that" do
    Aikotoba.scopes[:admin][:magic_link_path] = "/magic"
    Aikotoba.scopes[:admin][:recover_path] = "recover"
    Aikotoba.scopes[:admin][:confirm_path] = Aikotoba.default_scope[:confirm_path]
    Aikotoba.scopes[:admin][:after_sign_in_path] = "/"
    io = StringIO.new
    Aikotoba.scopes.warn_rewritten_paths(ActiveSupport::Logger.new(io))

    assert_equal 1, io.string.lines.size
    assert_includes io.string, %(admin.magic_link_path "/magic" is drawn as "/admin/magic"; write "/admin/magic" (or a relative path) to silence this.)
  end

  test "Scope#route_path leaves the default scope's paths as they are" do
    assert_equal "/sign_in", Aikotoba.default_scope.route_path(:sign_in_path)
    assert_equal "/magic_link", Aikotoba.default_scope.route_path(:magic_link_path)
  end

  test "an inherited path is drawn under the scope's root_path" do
    assert_equal "/magic_link", Aikotoba.scopes[:admin][:magic_link_path]
    admin_paths = Aikotoba::Engine.routes.routes.select { |route| route.name.to_s.start_with?("admin_") }.map { |route| route.path.spec.to_s }
    assert_includes admin_paths, "/admin/magic_link(.:format)"
    assert_includes admin_paths, "/admin/magic_link/:token(.:format)"
    assert admin_paths.all? { |path| path.start_with?("/admin/") }, "every admin route is under /admin"
  end
end
