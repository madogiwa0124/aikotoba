# frozen_string_literal: true

module Aikotoba
  class ApplicationController < ::ApplicationController
    include EnabledFeatureCheckable

    helper_method :enable_confirm?, :enable_lock?, :enable_recover?

    def aikotoba_controller?
      true
    end
  end
end
