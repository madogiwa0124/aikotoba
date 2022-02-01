class ApplicationController < ActionController::Base
  include Aikotoba::Authenticatable

  alias_method :current_account, :aikotoba_current_account

  def authenticate_account!
    return if current_account
    redirect_to aikotoba.new_session_path, flash: {alert: "Oops. You need to Signed up or Signed in." }
  end
end
