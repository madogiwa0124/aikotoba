class ApplicationController < ActionController::Base
  include Aikotoba::Authenticatable

  alias_method :current_account, :aikotoba_current_account

  helper_method :current_account, :aikotoba_scoped_path

  def authenticate_account!
    return if current_account
    redirect_to aikotoba_scoped_path(:new_session_path), flash: {alert: "Oops. You need to Signed up or Signed in." }
  end

  def authenticate_admin_account!
    return if current_account && current_account.admin.present?
    redirect_to aikotoba_scoped_path(:new_session_path), flash: {alert: "Oops. You need to Signed in as Admin." }
  end
end
