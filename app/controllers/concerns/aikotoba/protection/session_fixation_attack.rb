# frozen_string_literal: true

# NOTE:  Provides the ability to refresh session before sign_in for session fixation attacks.
# https://owasp.org/www-community/attacks/Session_fixation
module Aikotoba
  module Protection::SessionFixationAttack
    extend ActiveSupport::Concern

    def prevent_session_fixation_attack
      reflesh_session
    end

    private

    def reflesh_session
      old_session = session.dup.to_hash
      reset_session
      old_session.each_pair { |k, v| session[k.to_sym] = v }
    end
  end
end
