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

  # NOTE: Read a setting with Aikotoba.xxx. The Aikotoba.xxx= writers, add_scope and
  #       default_scope= are kept for initializers written before configure existed.
  class << self
    delegate(*Configuration::SETTINGS, :default_scope, to: :config)
    delegate(*Configuration::SETTINGS.map { |name| :"#{name}=" }, :default_scope=, :add_scope, to: :config)
  end
end
