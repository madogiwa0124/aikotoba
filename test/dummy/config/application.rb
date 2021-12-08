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
    config.action_mailer.delivery_method = :letter_opener_web
    config.action_mailer.default_url_options = {host: "localhost", port: 3000}
  end
end
