class ApplicationController < ActionController::Base
  include Aikotoba::Authenticatable

  alias_method :current_account, :aikotoba_current_account

  helper_method :current_account, :aikotoba_scoped_path

  # NOTE: Aikotoba's controllers inherit this one, so a before_action here runs before them.
  #       Covered by test/controllers/before_aikotoba_action_test.rb; the README's
  #       "Do something before, after, or on failure" shows the same shape.
  BLOCKED_IP = "203.0.113.1"
  before_action :reject_blocked_ip, if: -> { is_a?(Aikotoba::ApplicationController) }

  def authenticate_account!
    return if current_account
    aikotoba_request_authentication flash: {alert: "Oops. You need to Signed up or Signed in." }
  end

  def authenticate_admin_account!
    return if current_account && current_account.admin.present?
    aikotoba_request_authentication flash: {alert: "Oops. You need to Signed in as Admin." }
  end

  private

  def reject_blocked_ip
    head :forbidden if request.remote_ip == BLOCKED_IP
  end
end
