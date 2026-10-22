# frozen_string_literal: true

require "active_support/hash_with_indifferent_access"
require "aikotoba/scope"

module Aikotoba
  # NOTE: All scopes, keyed by name. Still a HashWithIndifferentAccess, so Aikotoba.scopes
  #       keeps its documented Hash behavior; the cross-scope rules live here.
  class Scopes < ActiveSupport::HashWithIndifferentAccess
    def default
      self[:default]
    end

    def add(name, config = {})
      scope = default.merge(config)
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

    # NOTE: Run by the Engine after initialization. route_path prefixes any path outside
    #       root_path; for one inherited from the default scope or written relative that is
    #       the intent, but an absolute path set on the scope itself was probably meant as is.
    #       A value equal to the default scope's can't be told from an inherited one, so it is
    #       treated as inherited.
    def warn_rewritten_paths(logger = Rails.logger)
      except(:default).each do |name, scope|
        scope.route_path_keys.each do |key|
          path = scope[key]
          rewritten = !scope.covers?(path)
          absolute = path.start_with?("/")
          same_as_default = path == default[key]
          next unless rewritten && absolute && !same_as_default

          route = scope.route_path(key)
          logger&.warn("[Aikotoba] #{name}.#{key} #{path.inspect} is drawn as #{route.inspect}; " \
            "write #{route.inspect} (or a relative path) to silence this.")
        end
      end
    end

    # NOTE: Checked by add, and again after initialization (Engine), to catch default_scope=
    #       or direct edits made afterwards.
    def validate!(scopes = self)
      validate_root_paths!(scopes)
      validate_unique_authenticate_for!(scopes)
    end

    private

    # NOTE: An added scope serves the requests its root_path covers (Scope#covers?). One at "/"
    #       would take over every request, the host app's included, and a malformed one would
    #       leave its own pages to the default scope. add_scope copies root_path "/" from the
    #       default scope unless it is set.
    def validate_root_paths!(scopes)
      invalid = scopes.except(:default).filter_map { |name, scope| name unless scope.valid_root_path? }
      return if invalid.empty?

      details = invalid.map { |name| "#{name} (#{scopes[name][:root_path].inspect})" }.join(", ")
      raise Errors::InvalidScopeConfiguration,
        "root_path of an added scope must be an absolute path other than \"/\", like \"/admin\", but is not on: " \
        "#{details}. add_scope copies root_path \"/\" from the default scope unless you set it."
    end

    # NOTE: Each authenticate_for may belong to one scope only, so an account's type maps to
    #       exactly one scope (see name_for).
    def validate_unique_authenticate_for!(scopes)
      shared = scopes
        .select { |_, scope| scope.authenticate_for.present? }
        .group_by { |_, scope| scope.authenticate_for.to_s }
        .select { |_, entries| entries.size > 1 }
      return if shared.empty?

      details = shared.map { |type, entries| "#{type} (#{entries.map(&:first).join(", ")})" }.join("; ")
      raise Errors::InvalidScopeConfiguration,
        "authenticate_for must be unique per scope, but is shared: #{details}. " \
        "add_scope copies authenticate_for from the default scope unless you set it, so set it " \
        "explicitly on the added scope (nil for an unrestricted scope)."
    end

    # NOTE: HashWithIndifferentAccess turns every Hash it stores into a plain
    #       HashWithIndifferentAccess; store a Scope instead, so a scope assigned directly
    #       (scopes[:name] = {...}) still answers registerable? / for?. Same private hook and
    #       signature in Rails 7.2 and 8.1. :to_hash is the conversion back to a plain Hash.
    def convert_value(value, conversion: nil)
      return Scope.new(value) if value.is_a?(Hash) && !value.is_a?(Scope) && conversion != :to_hash

      super
    end
  end
end
