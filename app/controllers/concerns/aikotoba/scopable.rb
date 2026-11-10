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
      @aikotoba_scope ||= Aikotoba.scopes.name_for_path(aikotoba_scope_path).inquiry
    end

    private

    def aikotoba_authenticate_target
      aikotoba_scope_config.authenticate_for
    end

    # NOTE: root_path is relative to the engine's mount point, so the path matched against it
    #       has the mount point removed (nil, the default scope, when outside it).
    #       Controllers in the engine's namespace (_routes is the engine's) get that as path_info.
    #       Requests the host app routes, a subclass of an Aikotoba controller included, get
    #       path_info relative to the app; original_script_name keeps relative_url_root out of
    #       the mount point, as path_info leaves out the app's SCRIPT_NAME.
    def aikotoba_scope_path
      return request.path_info if _routes.equal?(Aikotoba::Engine.routes)

      mount_path = Aikotoba::Engine.routes.find_script_name(original_script_name: true).chomp("/")
      path = request.path_info
      if path == mount_path
        "/"
      elsif path.start_with?("#{mount_path}/")
        path.delete_prefix(mount_path)
      end
    end
  end
end
