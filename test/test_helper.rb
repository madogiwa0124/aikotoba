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

# NOTE: Every test starts from the configuration the dummy app booted with, whatever earlier
#       tests set. Swapped in after_teardown, so a test's own teardown still sees its settings.
#       ActionController::Base.allow_forgery_protection is process-wide too (many integration
#       tests turn it off in setup), so it is put back the same way.
module AikotobaConfigurationReset
  def before_setup
    @aikotoba_booted_config = Aikotoba.config.dup
    @aikotoba_allow_forgery_protection = ActionController::Base.allow_forgery_protection
    super
  end

  def after_teardown
    super
    ActionController::Base.allow_forgery_protection = @aikotoba_allow_forgery_protection
    Aikotoba.instance_variable_set(:@config, @aikotoba_booted_config)
  end
end
ActiveSupport::TestCase.include AikotobaConfigurationReset

# NOTE: The engine's own code and tests must not use the deprecated Aikotoba.xxx= writers;
#       ConfigurationTest checks them with assert_deprecated, which collects instead.
Aikotoba.deprecator.behavior = :raise
