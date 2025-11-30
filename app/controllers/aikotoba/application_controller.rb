# frozen_string_literal: true

module Aikotoba
  class ApplicationController < Aikotoba.parent_controller.constantize
    include EnabledFeatureCheckable

    helper_method :confirmable?, :lockable?, :recoverable?, :registerable?

    def aikotoba_controller?
      true
    end

    def namespace
      # TODO: :default以外のnamespaceを取得してチェックする処理を実装
      Aikotoba.namespaces..each do |name, config|
        return name if request.path.start_with?(config[:root_path])
      end
      :default
    end
  end
end
