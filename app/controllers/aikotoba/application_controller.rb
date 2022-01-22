# frozen_string_literal: true

module Aikotoba
  class ApplicationController < ::ApplicationController
    include EnabledFeatureCheckable

    helper_method :confirmable?, :lockable?, :recoverable?, :registerable?

    def aikotoba_controller?
      true
    end
  end
end
