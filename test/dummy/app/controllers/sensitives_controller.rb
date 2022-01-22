class SensitivesController < ApplicationController
  before_action :authenticate_account!

  def index
    @account = current_account
  end
end
