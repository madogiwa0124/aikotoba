class Api::ApplicationController < ActionController::API
  include Aikotoba::Api::Authenticatable

  alias_method :current_api_account, :aikotoba_api_current_account

  def authenticate_api_account!
    return if current_api_account

    render json: { error: "Unauthorized" }, status: :unauthorized
  end
end
