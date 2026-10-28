# frozen_string_literal: true

require "aikotoba/version"
require "aikotoba/engine"
require "aikotoba/errors"
require "aikotoba/configuration"

module Aikotoba
  # NOTE: Set every setting in one place:
  #       Aikotoba.configure do |config|
  #         config.confirmable = true
  #         config.add_scope(:admin, { root_path: "/admin", authenticate_for: "Admin" })
  #       end
  #       The scopes are checked once the block has set everything, feature flags included.
  def self.configure
    yield config
    scopes.validate!
  end

  def self.config
    @config ||= Configuration.new
  end

  def self.deprecator
    @deprecator ||= ActiveSupport::Deprecation.new("1.0", "Aikotoba")
  end

  # NOTE: Read a setting with Aikotoba.xxx. The Aikotoba.xxx= writers, add_scope and
  #       default_scope= still work for initializers written before configure existed, but
  #       are deprecated and will be removed in 1.0.
  class << self
    delegate(*Configuration::SETTINGS, :default_scope, to: :config)

    Configuration::SETTINGS.each do |name|
      define_method(:"#{name}=") do |value|
        deprecator.warn("Aikotoba.#{name}= is deprecated. Set config.#{name} in Aikotoba.configure instead.")
        config.public_send(:"#{name}=", value)
      end
    end

    def default_scope=(hash)
      deprecator.warn("Aikotoba.default_scope= is deprecated. Set config.default_scope in Aikotoba.configure instead.")
      config.default_scope = hash
    end

    def add_scope(name, scope_config = {})
      deprecator.warn("Aikotoba.add_scope is deprecated. Call config.add_scope in Aikotoba.configure instead.")
      config.add_scope(name, scope_config)
    end
  end
end
