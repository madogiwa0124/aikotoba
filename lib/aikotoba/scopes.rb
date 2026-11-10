# frozen_string_literal: true

require "active_support/hash_with_indifferent_access"
require "aikotoba/scope"

module Aikotoba
  # NOTE: All scopes, keyed by name. Still a HashWithIndifferentAccess, so Aikotoba.scopes
  #       keeps its documented Hash behavior; the cross-scope rules live here.
  class Scopes < ActiveSupport::HashWithIndifferentAccess
    # NOTE: Not named default: that would override Hash#default(key = nil), which Hash calls
    #       with the key on every miss (scopes[:typo] raised ArgumentError), and which
    #       HashWithIndifferentAccess copies into every dup (select, reject, deep_dup), turning
    #       the default scope into the copy's fallback value for missing keys.
    def default_scope
      self[:default]
    end

    def add(name, config = {})
      scope = default_scope.merge(config)
      validate!(merge(name => scope))
      self[name] = scope
    end

    # NOTE: The scope whose links an account's emails use: the scope whose authenticate_for
    #       matches the account's target type (unique, see validate!), else the default.
    #       Emails are rendered in a job, with no request to tell which scope was used.
    def name_for(target_type_name)
      name, _ = find { |_, scope| scope.for?(target_type_name) }
      name || "default"
    end

    # NOTE: The scope a path (relative to the engine's mount point) belongs to: the first added
    #       scope whose root_path covers it, else the default. Scopable resolves requests with
    #       this, and validate! checks every route with it, so the two can't disagree.
    def name_for_path(path)
      return "default" if path.nil?

      each do |name, scope|
        next if name == "default"
        return name if scope.covers?(path)
      end
      "default"
    end

    # NOTE: Run by the Engine after initialization. route_path prefixes any path outside
    #       root_path; for one inherited from the default scope or written relative that is
    #       the intent, but an absolute path set on the scope itself was probably meant as is.
    #       A value equal to the default scope's can't be told from an inherited one, so it is
    #       treated as inherited.
    #       A logger passed in gets the "[Aikotoba]" prefix too; nil logs nothing.
    def warn_rewritten_paths(logger = Aikotoba.logger)
      return if logger.nil?

      logger = PrefixedLogger.new(logger) unless logger.is_a?(PrefixedLogger)
      except(:default).each do |name, scope|
        scope.route_path_keys.each do |key|
          path = scope[key]
          rewritten = !scope.covers?(path)
          absolute = path.start_with?("/")
          same_as_default = path == default_scope[key]
          next unless rewritten && absolute && !same_as_default

          route = scope.route_path(key)
          logger.warn("#{name}.#{key} #{path.inspect} is drawn as #{route.inspect}; " \
            "write #{route.inspect} (or a relative path) to silence this.")
        end
      end
    end

    # NOTE: Checked by add, and again after initialization (Engine), to catch default_scope=
    #       or direct edits made afterwards.
    def validate!(scopes = self)
      validate_root_paths!(scopes)
      validate_routes_served_as_own_scope!(scopes)
      validate_unique_authenticate_for!(scopes)
      validate_unique_session_keys!(scopes)
    end

    private

    # NOTE: An added scope serves the requests its root_path covers (Scope#covers?). One at "/"
    #       would take over every request, the host app's included, and a malformed one would
    #       leave its own pages to the default scope. add_scope copies root_path "/" from the
    #       default scope unless it is set.
    def validate_root_paths!(scopes)
      invalid = scopes.except(:default).reject { |_, scope| scope.valid_root_path? }
      return if invalid.empty?

      details = invalid.map { |name, scope| "#{name} (#{scope[:root_path].inspect})" }.join(", ")
      raise Errors::InvalidScopeConfiguration,
        "root_path of an added scope must be an absolute path other than \"/\", like \"/admin\", but is not on: " \
        "#{details}. add_scope copies root_path \"/\" from the default scope unless you set it."
    end

    # NOTE: Each route a scope draws must be served as that scope, as name_for_path (what
    #       Scopable uses) resolves it. Two added scopes at the same root_path fail it, as does
    #       one under another added before it ("/admin/super" after "/admin"), whose routes
    #       resolve to the earlier scope; so does a default scope path under an added
    #       root_path (sign_in_path: "/admin/login" with an "/admin" scope).
    def validate_routes_served_as_own_scope!(scopes)
      misrouted = scopes.flat_map do |name, scope|
        scope.route_path_keys.filter_map do |key|
          drawn_path = scope.route_path(key)
          served_as = scopes.name_for_path(drawn_path)
          next if served_as == name

          "#{name}.#{key} (#{drawn_path.inspect}, served as #{served_as})"
        end
      end
      return if misrouted.empty?

      raise Errors::InvalidScopeConfiguration,
        "every route of a scope must be served as that scope, but is not on: #{misrouted.join(", ")}. " \
        "An added scope's root_path must not be the same as, or under, an earlier added scope's, " \
        "and no path of the default scope may be under an added scope's root_path."
    end

    # NOTE: The session cookie is named by session_key. Two scopes sharing one read each other's
    #       cookie: an unrestricted scope accepts the other's sessions, and a restricted one
    #       deletes the cookie of a session it doesn't accept, signing the other scope out.
    #       add_scope copies session_key from the default scope unless it is set.
    def validate_unique_session_keys!(scopes)
      names_with_blank_key = scopes.select { |_, scope| scope[:session_key].blank? }.keys
      names_by_shared_key = shared_values(scopes) { |scope| scope[:session_key] }
      return if names_with_blank_key.empty? && names_by_shared_key.empty?

      blank_details = names_with_blank_key.map { |name| "#{name} (blank)" }
      shared_details = names_by_shared_key.map { |key, names| "#{key} (#{names.join(", ")})" }
      details = blank_details + shared_details
      raise Errors::InvalidScopeConfiguration,
        "session_key must be present and unique per scope, but is not on: #{details.join("; ")}. " \
        "add_scope copies session_key from the default scope unless you set it, so set it on the added scope."
    end

    # NOTE: Each authenticate_for may belong to one scope only, so an account's type maps to
    #       exactly one scope (see name_for).
    def validate_unique_authenticate_for!(scopes)
      names_by_shared_type = shared_values(scopes, &:authenticate_for)
      return if names_by_shared_type.empty?

      details = names_by_shared_type.map { |type, names| "#{type} (#{names.join(", ")})" }.join("; ")
      raise Errors::InvalidScopeConfiguration,
        "authenticate_for must be unique per scope, but is shared: #{details}. " \
        "add_scope copies authenticate_for from the default scope unless you set it, so set it " \
        "explicitly on the added scope (nil for an unrestricted scope)."
    end

    # NOTE: {value => scope names} for each present value of a setting that more than one
    #       scope has, compared as strings (so authenticate_for: Admin and "Admin" match).
    def shared_values(scopes)
      scopes
        .group_by { |_, scope| yield(scope).to_s }
        .reject { |value, _| value.blank? }
        .transform_values { |entries| entries.map(&:first) }
        .select { |_, names| names.size > 1 }
    end

    # NOTE: HashWithIndifferentAccess turns every Hash it stores into a plain
    #       HashWithIndifferentAccess; store a Scope instead, so a scope assigned directly
    #       (scopes[:name] = {...}) still answers registerable? / for?. :to_hash is the
    #       conversion back to a plain Hash.
    def convert_value(value, conversion: nil)
      return Scope.new(value) if value.is_a?(Hash) && !value.is_a?(Scope) && conversion != :to_hash

      super
    end
  end
end
