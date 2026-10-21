# frozen_string_literal: true

module Aikotoba
  class Engine < ::Rails::Engine
    isolate_namespace Aikotoba

    # NOTE: Runs once the host app's initializers (where add_scope / default_scope= live)
    #       are done. Not in config/routes.rb: Rails 8 draws routes lazily in development
    #       and test, so a check there would only fire on the first request.
    config.after_initialize { Aikotoba.validate_scopes! }
  end
end
