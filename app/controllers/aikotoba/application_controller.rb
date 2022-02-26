# frozen_string_literal: true

module Aikotoba
  class ApplicationController < Aikotoba.parent_controller.constantize
    include EnabledFeatureCheckable

    helper_method :confirmable?, :lockable?, :recoverable?, :registerable?

    def aikotoba_controller?
      true
    end
  end
end
