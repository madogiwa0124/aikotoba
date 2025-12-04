# frozen_string_literal: true

module Aikotoba
  class ApplicationController < Aikotoba.parent_controller.constantize
    include EnabledFeatureCheckable
    include Scopable

    helper_method :confirmable?, :lockable?, :recoverable?, :registerable?, :aikotoba_scoped_path

    def aikotoba_controller?
      true
    end
  end
end
