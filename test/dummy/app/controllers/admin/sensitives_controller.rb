class Admin::SensitivesController < ApplicationController
  before_action :authenticate_admin_account!

  def index
    @account = current_account
  end
end
