# frozen_string_literal: true

module Aikotoba
  # NOTE: Reports "aikotoba.<event>" structured events through Rails.event. Events are
  #       reported from the models and the sign in helpers rather than the controllers, so
  #       an app's own controller built on them reports the same events. Payloads hold plain
  #       values (ids, names), not records, since subscribers serialize them.
  module Events
    module_function

    # NOTE: For something that happened (account_registered, account_locked, ...). Waits for
    #       every open transaction, the caller's included, to commit and is dropped on
    #       rollback, so a subscriber never hears about a change that didn't persist. Runs
    #       right away when no transaction is open.
    def report_after_commit(event, **payload)
      ActiveRecord.after_all_transactions_commit { report(event, **payload) }
    end

    # NOTE: For an attempt that failed (sign_in_failed): there is nothing to commit, and
    #       the attempt happened whatever the caller's transaction does.
    def report(event, **payload)
      Rails.event.notify("aikotoba.#{event}", payload)
    end
  end
end
