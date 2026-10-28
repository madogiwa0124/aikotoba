# NOTE: Calls aikotoba_sign_out without reading the current account first, as an app's own
#       sign out action may.
class SignOutsController < ApplicationController
  def destroy
    aikotoba_sign_out
    head :no_content
  end
end
