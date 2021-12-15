# frozen_string_literal: true

module Aikotoba
  class ApplicationController < ::ApplicationController
    helper_method :enable_confirm?

    def aikotoba_controller?
      true
    end

    def enable_confirm?
      Aikotoba.enable_confirm
    end
  end
end
