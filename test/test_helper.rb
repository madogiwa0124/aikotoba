# Configure Rails Environment
ENV["RAILS_ENV"] = "test"

require "simplecov"
SimpleCov.start :rails do
  add_filter "/test/"
  add_filter "/vendor/"
  enable_coverage :branch
end

require_relative "../test/dummy/config/environment"
ActiveRecord::Migrator.migrations_paths = [File.expand_path("../test/dummy/db/migrate", __dir__)]
ActiveRecord::Migrator.migrations_paths << File.expand_path("../db/migrate", __dir__)
require "rails/test_help"

# Load fixtures from the engine
if ActiveSupport::TestCase.respond_to?(:fixture_path=)
  ActiveSupport::TestCase.fixture_path = File.expand_path("fixtures", __dir__)
  ActionDispatch::IntegrationTest.fixture_path = ActiveSupport::TestCase.fixture_path
  ActiveSupport::TestCase.file_fixture_path = ActiveSupport::TestCase.fixture_path + "/files"
  ActiveSupport::TestCase.fixtures :all
end

require "capybara/rails"
Capybara.server = :webrick, {Silent: true} # To clean up your test output
require "aikotoba/test/authentication_helper"
require "committee/rails"
require "support/api_committee_helper"

# NOTE: Every test starts from the configuration the dummy app booted with, whatever earlier
#       tests set. Swapped in after_teardown, so a test's own teardown still sees its settings.
module AikotobaConfigurationReset
  def before_setup
    @aikotoba_booted_config = Aikotoba.config.dup
    super
  end

  def after_teardown
    super
    Aikotoba.instance_variable_set(:@config, @aikotoba_booted_config)
  end
end
ActiveSupport::TestCase.include AikotobaConfigurationReset

# NOTE: The engine's own code and tests must not use the deprecated Aikotoba.xxx= writers;
#       ConfigurationTest checks them with assert_deprecated, which collects instead.
Aikotoba.deprecator.behavior = :raise
