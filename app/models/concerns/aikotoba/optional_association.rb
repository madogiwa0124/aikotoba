# frozen_string_literal: true

module Aikotoba
  # NOTE: Support for has_one associations whose table is optional -- a host app that
  #       never enables the owning feature may legitimately never run its migration (see
  #       the README's Getting Start section). `dependent: :destroy` can't be used for
  #       those, because it registers an unconditional callback that loads the association
  #       on every parent destroy; that is what raised PG::UndefinedTable for host apps
  #       with a feature off and its table never created.
  module OptionalAssociation
    extend ActiveSupport::Concern

    module ClassMethods
      SUPPORTED_DEPENDENT_OPTIONS = [nil, :destroy].freeze

      # NOTE: Declares a has_one whose table may not exist. Behaves like plain `has_one`
      #       in every respect except one: with `dependent: :destroy`, the callback that
      #       cleans the child up is gated on the table actually existing.
      #
      #       That gate is the whole point. Rails' own `dependent: :destroy` callback is
      #       unconditional -- it loads the association on every parent destroy whether or
      #       not the table is there -- which is what raised PG::UndefinedTable. Gating on
      #       the table's existence (rather than on the owning feature's flag) keeps
      #       destroy working in *both* directions: no table means the reader is never
      #       called and the table is never queried, while a table left behind after a
      #       flag was switched off still gets cleaned up instead of stranding the row and
      #       raising ActiveRecord::InvalidForeignKey.
      #
      #       Only `dependent: :destroy` (or no :dependent at all) is supported. The other
      #       values would have to be forwarded to has_one to work, which would register
      #       the unconditional callback this exists to avoid, so they raise rather than
      #       silently doing nothing.
      #
      #       Not every optional association wants the callback. Where the owner already
      #       carries a cheaper invariant that decides whether a child can exist at all,
      #       guard on that instead -- Account::Session#refresh_token declares its has_one
      #       by hand and guards on origin_api?, which skips the association load entirely
      #       rather than only skipping it when the table is missing. See the NOTE there.
      def optional_has_one(name, **options)
        dependent = options.delete(:dependent)
        unless SUPPORTED_DEPENDENT_OPTIONS.include?(dependent)
          raise ArgumentError,
            "optional_has_one supports dependent: :destroy only, got #{dependent.inspect}"
        end

        has_one(name, **options)
        return if dependent.nil?

        # NOTE: `dependent: :destroy` does two separate jobs and we want exactly one of
        #       them, so it is deliberately withheld from has_one above and set here
        #       instead. Order matters:
        #
        #       - Withheld: has_one reads :dependent at *declaration* time to register the
        #         unconditional before_destroy. Never passing it means that callback is
        #         never created, and setting the option afterwards cannot retroactively
        #         create it. The guarded equivalent is registered below.
        #       - Restored: HasOneAssociation#remove_target! reads :dependent out of the
        #         reflection at *runtime*, to clear the previous record when a new one
        #         replaces it. Without it, `build_<name>` + `save!` would try to nullify
        #         the old row's NOT NULL foreign key and raise
        #         ActiveRecord::RecordNotSaved, so every caller would need to hand-roll a
        #         destroy first.
        reflect_on_association(name).options[:dependent] = dependent

        before_destroy do
          # NOTE: Resolved per call rather than at declaration time to avoid autoloading
          #       the associated model while this one is still being defined. It reads
          #       table_name off the class, which is derived from the class name and so
          #       needs no database access of its own.
          table_name = self.class.reflect_on_association(name).klass.table_name
          public_send(name)&.destroy if self.class.table_exists_in_schema_cache?(table_name)
        end
      end

      # NOTE: Served from the schema cache -- negative results are cached too -- so this
      #       costs at most one query per process rather than one per destroy. Like
      #       anything schema-cached, a process that was already running when the
      #       migration was applied needs a restart to notice the new table.
      #       connection_pool#schema_cache is the current home for it; older supported
      #       Rails versions keep it on the connection, hence the fallback.
      def table_exists_in_schema_cache?(table_name)
        pool = connection_pool
        cache = pool.respond_to?(:schema_cache) ? pool.schema_cache : connection.schema_cache
        cache.data_source_exists?(table_name)
      end
    end
  end
end
