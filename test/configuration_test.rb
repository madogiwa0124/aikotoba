# frozen_string_literal: true

require "test_helper"

class Aikotoba::ConfigurationTest < ActiveSupport::TestCase
  test "configure yields the configuration that Aikotoba.xxx reads" do
    Aikotoba.configure do |config|
      config.confirmable = true
      config.max_failed_attempts = 3
      config.default_scope = {sign_in_path: "/login"}
    end

    assert Aikotoba.confirmable
    assert_equal 3, Aikotoba.max_failed_attempts
    assert_equal "/login", Aikotoba.default_scope[:sign_in_path]
    assert_same Aikotoba.config.scopes, Aikotoba.scopes
  end

  test "configure checks the scopes once the block is done, with every setting in place" do
    error = assert_raises(Aikotoba::Errors::InvalidScopeConfiguration) do
      Aikotoba.configure { |config| config.scopes[:admin][:root_path] = "/" }
    end
    assert_match %(admin ("/")), error.message
  end

  test "add_scope inside configure adds a scope under its root_path" do
    Aikotoba.configure do |config|
      config.add_scope(:staff, root_path: "/staff", authenticate_for: "Staff")
    end

    assert_equal "/staff", Aikotoba.scopes[:staff][:root_path]
    assert Aikotoba.scopes[:staff].for?("Staff")
  end

  test "the Aikotoba.xxx writers still set the configuration, with a deprecation warning" do
    assert_deprecated(/Aikotoba.lockable= is deprecated/, Aikotoba.deprecator) { Aikotoba.lockable = true }
    assert_deprecated(/Aikotoba.default_scope= is deprecated/, Aikotoba.deprecator) { Aikotoba.default_scope = {sign_in_path: "/login"} }
    assert_deprecated(/Aikotoba.add_scope is deprecated/, Aikotoba.deprecator) do
      Aikotoba.add_scope(:staff, root_path: "/staff", authenticate_for: "Staff")
    end

    assert Aikotoba.config.lockable
    assert_equal "/login", Aikotoba.default_scope[:sign_in_path]
    assert Aikotoba.config.scopes.key?(:staff)
  end

  test "the deprecator is registered with the app" do
    assert_same Aikotoba.deprecator, Rails.application.deprecators[:aikotoba]
  end

  test "a new configuration has the documented defaults" do
    config = Aikotoba::Configuration.new

    assert_equal "ApplicationController", config.parent_controller
    assert_equal 7.days, config.session_expiry
    assert config.registerable
    assert_not config.confirmable
    assert_equal({}, config.confirmation_rate_limit_options)
    assert_equal "/", config.default_scope[:root_path]
    assert_equal ["default"], config.scopes.keys
  end

  # NOTE: attr_accessor doesn't check that initialize sets each setting. A setting with no
  #       default would read as nil, and a default missing from SETTINGS would get no reader
  #       and be shared, not deep-copied, by initialize_copy.
  test "initialize sets exactly the SETTINGS" do
    assert_equal Aikotoba::Configuration::SETTINGS.map { |name| :"@#{name}" }.sort,
      Aikotoba::Configuration.new.instance_variables.sort
  end

  test "a copy shares no mutable value with the original" do
    original = Aikotoba::Configuration.new
    copy = original.dup

    copy.default_scope[:sign_in_path] = "/login"
    copy.add_scope(:staff, root_path: "/staff")
    copy.confirmation_rate_limit_options[:to] = 3

    assert_equal "/sign_in", original.default_scope[:sign_in_path]
    assert_not original.scopes.key?(:staff)
    assert_equal({}, original.confirmation_rate_limit_options)
    assert_instance_of Aikotoba::Scopes, copy.scopes
  end

  test "every setting is readable through Aikotoba and writable through config" do
    Aikotoba::Configuration::SETTINGS.each do |name|
      assert_respond_to Aikotoba, name
      assert_respond_to Aikotoba.config, :"#{name}="
    end
  end
end
