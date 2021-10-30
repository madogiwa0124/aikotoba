# frozen_string_literal: true

module Aikotoba
  class ApplicationController < ::ApplicationController
    def aikotoba_controller?
      true
    end
  end
end
