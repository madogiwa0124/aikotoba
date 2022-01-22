# frozen_string_literal: true

module Aikotoba
  module EnabledFeatureCheckable
    extend ActiveSupport::Concern

    module ClassMethods
      def registerable?
        Aikotoba.registerable
      end

      def lockable?
        Aikotoba.lockable
      end

      def confirmable?
        Aikotoba.confirmable
      end

      def recoverable?
        Aikotoba.recoverable
      end
    end

    def registerable?
      self.class.registerable?
    end

    def lockable?
      self.class.lockable?
    end

    def confirmable?
      self.class.confirmable?
    end

    def recoverable?
      self.class.recoverable?
    end
  end
end
