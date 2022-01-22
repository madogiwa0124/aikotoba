class ApplicationController < ActionController::Base
  include Aikotoba::Authenticatable

  def authenticate_user!
    return if current_user
    redirect_to aikotoba.new_session_path, flash: {alert: "Oops. You need to Signed up or Signed in." }
  end
end
