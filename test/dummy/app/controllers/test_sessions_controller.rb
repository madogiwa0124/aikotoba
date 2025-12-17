class TestSessionsController < ActionController::Base
  def set_legacy_session
    session[params[:key]] = params[:value].to_i
    render json: { ok: true }
  end
end
