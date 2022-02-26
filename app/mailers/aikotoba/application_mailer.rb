module Aikotoba
  class ApplicationMailer < Aikotoba.parent_mailer.constantize
    default from: Aikotoba.mailer_sender
  end
end
