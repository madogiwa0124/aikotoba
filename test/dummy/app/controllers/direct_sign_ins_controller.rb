# NOTE: Calls aikotoba_sign_in straight away, as an app's own controller might by mistake in a
#       scope that requires a second factor, so test/controllers/direct_sign_in_test.rb can
#       check that it is refused. Not an example to follow: it checks no credential at all.
class DirectSignInsController < ApplicationController
  def create
    account = Aikotoba::Account.find_by!(email: params[:email])
    two_factor = params[:two_factor].presence&.to_sym
    aikotoba_sign_in(account, two_factor: two_factor)
    head :no_content
  end
end
