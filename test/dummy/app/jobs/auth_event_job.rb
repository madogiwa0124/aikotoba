# NOTE: The job the README's Events example enqueues (config/initializers/aikotoba_events.rb).
#       An app would write the event to its audit log here; the dummy only logs it.
class AuthEventJob < ActiveJob::Base
  def perform(name, payload, context)
    Rails.logger.info("[AuthEventJob] #{name} #{payload.inspect} #{context.inspect}")
  end
end
