# frozen_string_literal: true

require "active_support/hash_with_indifferent_access"

module Aikotoba
  # NOTE: One scope's settings. Still a HashWithIndifferentAccess, so the documented
  #       Aikotoba.default_scope[:key] / Aikotoba.scopes[:name][:key] reads and writes keep
  #       working; the methods below answer the questions callers used to ask of the raw hash.
  class Scope < ActiveSupport::HashWithIndifferentAccess
    def authenticate_for
      self[:authenticate_for]
    end

    # NOTE: A scope restricted by authenticate_for gets no sign-up: its accounts need an
    #       authenticate_target of that type, which the generic sign-up form can't create.
    #       Routes and the sign-in page's sign-up link both read this, so they can't disagree.
    #       blank? (not nil?) matches Account.for_target_type, which treats "" as unrestricted.
    def registerable?
      authenticate_for.blank?
    end

    # NOTE: Whether this is the scope set up for the target type (authenticate_for: "Admin"
    #       for "Admin"). An unrestricted scope also signs Admins in, but isn't "for" them.
    def for?(target_type_name)
      authenticate_for.present? && authenticate_for.to_s == target_type_name.to_s
    end

    # NOTE: Whether a request path belongs to this scope. Scopable resolves the current
    #       scope with this, so route_path keeps each route inside it.
    #       A trailing slash on root_path is ignored, so "/admin/" covers "/admin/sign_in" too.
    def covers?(path)
      path == root || path.start_with?("#{root}/")
    end

    # NOTE: An absolute path with at least one segment ("/admin", "/admin/", "/a/b"), the
    #       only shape covers? handles: "/" (or unset) would cover every request, and a
    #       relative or malformed one ("admin", "/admin//") none, not even its own routes.
    def valid_root_path?
      self[:root_path].to_s.match?(%r{\A(/[^/\s]+)+/?\z})
    end

    # NOTE: The path config/routes.rb draws for a path setting: the value as is when it is
    #       already under root_path, otherwise prefixed with root_path. So a path add_scope
    #       copied from the default scope (/magic_link in an /admin scope) still lands in this
    #       scope (/admin/magic_link), and "/admin/..." isn't prefixed twice. Only for routed
    #       paths; redirect targets like after_sign_in_path may point anywhere.
    def route_path(key)
      path = self[key]
      covers?(path) ? path : File.join(self[:root_path], path)
    end

    # NOTE: The *_path settings config/routes.rb draws through route_path; the others are
    #       the scope's own root and redirect targets, which may point anywhere.
    def route_path_keys
      keys.select { |key| key.end_with?("_path") } - %w[root_path after_sign_in_path after_sign_out_path]
    end

    private

    def root
      self[:root_path].to_s.chomp("/")
    end
  end
end
