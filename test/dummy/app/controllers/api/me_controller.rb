# frozen_string_literal: true

module Api
  class MeController < ApplicationController
    before_action :authenticate_api_account!

    def show
      render json: {
        account: {
          id: current_api_account.id,
          authenticate_target_type: current_api_account.authenticate_target_type,
          authenticate_target_id: current_api_account.authenticate_target_id
        }
      }
    end
  end
end
