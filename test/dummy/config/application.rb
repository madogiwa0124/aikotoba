require 'active_record/railtie'
require 'action_controller/railtie'
require 'action_view/railtie'
require 'action_mailer/railtie'

ENV['BUNDLE_GEMFILE'] ||= File.expand_path('../../../Gemfile', __dir__)

require "bundler/setup" if File.exist?(ENV["BUNDLE_GEMFILE"])
$LOAD_PATH.unshift File.expand_path('../../../lib', __dir__)

Bundler.require(*Rails.groups)
require "aikotoba"

module Dummy
  class Application < Rails::Application
    config.load_defaults Rails::VERSION::STRING.to_f
    config.assets.enabled = false
    config.cache_classes = false
    config.eager_load = false
    config.consider_all_requests_local = true
    config.action_controller.perform_caching = false
    config.cache_store = :null_store
    config.active_support.deprecation = :log
    config.active_support.disallowed_deprecation = :raise
    config.active_support.disallowed_deprecation_warnings = []
    config.active_record.migration_error = :page_load
    config.active_record.verbose_query_logs = true
    config.action_mailer.raise_delivery_errors = false
    config.action_mailer.perform_caching = false
    config.action_mailer.delivery_method = Rails.env.test? ? :test : :letter_opener_web
    config.action_mailer.default_url_options = {host: "localhost", port: 3000}
    # NOTE: use multiple databases
    if Rails.env.development?
      config.active_record.database_selector = { delay: 5.seconds }
      config.active_record.database_resolver = ActiveRecord::Middleware::DatabaseSelector::Resolver
      config.active_record.database_resolver_context = ActiveRecord::Middleware::DatabaseSelector::Resolver::Session
    end
    if ActiveRecord::VERSION::MAJOR >= 7
      config.active_record.encryption.primary_key = "foo"
      config.active_record.encryption.deterministic_key = "bar"
      config.active_record.encryption.key_derivation_salt = "baz"
    end
  end
end
