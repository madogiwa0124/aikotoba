# NOTE: The README's Events example, as is, so test/events_subscriber_test.rb can check that it
#       works: every aikotoba.* event reaches AuthEventJob, whose arguments Active Job must be
#       able to serialize. Keep it in step with the README.
class AuthEventSubscriber
  def emit(event)
    AuthEventJob.perform_later(event[:name], event[:payload], event[:context])
  end
end

Rails.event.subscribe(AuthEventSubscriber.new) { |event| event[:name].start_with?("aikotoba.") }
