# frozen_string_literal: true

module Aikotoba
  module Api
    class ApplicationController < Aikotoba.api_parent_controller.constantize
      include EnabledFeatureCheckable
      include Scopable

      protect_from_forgery with: :null_session

      rescue_from StandardError, with: :render_internal_server_error
      rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
      rescue_from ActionController::BadRequest, with: :render_bad_request
      rescue_from ActionController::ParameterMissing, with: :render_bad_request

      private

      def render_bad_request(exception)
        Rails.error.report(exception, severity: :warning)
        render_from_api_error(Api::Error.invalid_request)
      end

      def render_not_found(exception)
        Rails.error.report(exception, severity: :warning)
        render_from_api_error(Api::Error.not_found)
      end

      def render_internal_server_error(exception)
        Rails.error.report(exception, severity: :error)
        render_from_api_error(Api::Error.internal_server_error)
      end

      def render_from_api_error(error)
        render json: error.to_h, status: error.status, content_type: "application/problem+json"
      end

      def aikotoba_controller?
        true
      end
    end
  end
end
