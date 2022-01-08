# frozen_string_literal: true

module Aikotoba
  module EnabledFeatureCheckable
    extend ActiveSupport::Concern

    module ClassMethods
      def enable_lock?
        Aikotoba.enable_lock
      end

      def enable_confirm?
        Aikotoba.enable_confirm
      end

      def enable_recover?
        Aikotoba.enable_recover
      end
    end

    def enable_lock?
      self.class.enable_lock
    end

    def enable_confirm?
      self.class.enable_confirm
    end

    def enable_recover?
      self.class.enable_recover
    end
  end
end
