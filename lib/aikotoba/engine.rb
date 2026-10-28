# frozen_string_literal: true

module Aikotoba
  class Engine < ::Rails::Engine
    isolate_namespace Aikotoba

    initializer "aikotoba.deprecator" do |app|
      app.deprecators[:aikotoba] = Aikotoba.deprecator
    end

    # NOTE: Runs once the host app's initializers (where Aikotoba.configure lives) are done,
    #       to also catch scopes changed outside configure. Not in config/routes.rb: Rails 8
    #       draws routes lazily in development and test, so a check there would only fire on
    #       the first request.
    config.after_initialize do
      Aikotoba.scopes.validate!
      Aikotoba.scopes.warn_rewritten_paths
    end
  end
end
