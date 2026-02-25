module Aikotoba
  module Scopable
    extend ActiveSupport::Concern

    def aikotoba_scope_config
      Aikotoba.scopes[aikotoba_scope]
    end

    def aikotoba_scoped_path(path, *params)
      return aikotoba.public_send(path, *params) if aikotoba_scope.default?

      aikotoba.public_send("#{aikotoba_scope}_#{path}", *params)
    end

    def aikotoba_scope
      @aikotoba_scope ||= aikotoba_calc_scope_from(request.path).to_s.inquiry
    end

    private

    def aikotoba_calc_scope_from(request_path)
      scope = :default
      Aikotoba.scopes.except(:default).each do |name, config|
        if aikotoba_from_scope_path?(config[:root_path])
          scope = name
          break # NOTE: Adopt the first matching scope
        end
      end
      scope
    end

    def aikotoba_from_scope_path?(scope_root_path)
      request.path == scope_root_path || request.path.start_with?("#{scope_root_path}/")
    end
  end
end
