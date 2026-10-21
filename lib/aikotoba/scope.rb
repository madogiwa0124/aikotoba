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
  end
end
