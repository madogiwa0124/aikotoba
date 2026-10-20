# frozen_string_literal: true

module Aikotoba
  class ApplicationController < Aikotoba.parent_controller.constantize
    include EnabledFeatureCheckable
    include Scopable

    helper_method :confirmable?, :lockable?, :recoverable?, :registerable?, :magic_link_authenticatable?, :aikotoba_scoped_path, :aikotoba_scoped_path, :aikotoba_scope, :aikotoba_scope_registerable?

    def aikotoba_controller?
      true
    end

    private

    def aikotoba_scope_registerable?
      registerable? && Aikotoba.registerable_scope?(aikotoba_scope_config)
    end
  end
end
