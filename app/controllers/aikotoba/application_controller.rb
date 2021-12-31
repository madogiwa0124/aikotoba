# frozen_string_literal: true

module Aikotoba
  class ApplicationController < ::ApplicationController
    helper_method :enable_confirm?, :enable_lock?, :enable_recover?

    def aikotoba_controller?
      true
    end

    def enable_confirm?
      ::Aikotoba::Account.enable_confirm?
    end

    def enable_recover?
      ::Aikotoba::Account.enable_recover?
    end

    def enable_lock?
      ::Aikotoba::Account.enable_lock?
    end
  end
end
