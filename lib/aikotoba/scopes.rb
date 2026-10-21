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

    # NOTE: Each authenticate_for may belong to one scope only, so an account's type maps to
    #       exactly one scope (see name_for). Checked by add, and again after initialization
    #       (Engine), to catch default_scope= or direct edits made afterwards.
    def validate!(scopes = self)
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

    private

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
