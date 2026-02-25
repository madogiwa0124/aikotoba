# frozen_string_literal: true

# NOTE: RFC 9457
# https://www.rfc-editor.org/rfc/rfc9457.html

module Aikotoba
  module Api
    class Error
      def self.unauthorized(detail: I18n.t("aikotoba.api.errors.unauthorized.detail"))
        new(
          title: I18n.t("aikotoba.api.errors.unauthorized.title"),
          status: 401,
          detail: detail
        )
      end

      def self.invalid_request(detail: I18n.t("aikotoba.api.errors.invalid_request.detail"))
        new(
          title: I18n.t("aikotoba.api.errors.invalid_request.title"),
          status: 400,
          detail: detail
        )
      end

      def self.internal_server_error(detail: I18n.t("aikotoba.api.errors.internal_server_error.detail"))
        new(
          title: I18n.t("aikotoba.api.errors.internal_server_error.title"),
          status: 500,
          detail: detail
        )
      end

      def self.not_found(detail: I18n.t("aikotoba.api.errors.not_found.detail"))
        new(
          title: I18n.t("aikotoba.api.errors.not_found.title"),
          status: 404,
          detail: detail
        )
      end

      def self.unprocessable_entity(detail: I18n.t("aikotoba.api.errors.unprocessable_entity.detail"))
        new(
          title: I18n.t("aikotoba.api.errors.unprocessable_entity.title"),
          status: 422,
          detail: detail
        )
      end

      def initialize(title:, status:, detail: nil, instance: nil, **extension)
        @title = title
        @status = status
        @detail = detail
        @instance = instance
        @extension = extension
      end

      attr_reader :title, :status, :detail, :instance, :extension

      def to_h
        {
          title: title,
          status: status,
          detail: detail,
          instance: instance,
          **extension
        }.compact
      end
    end
  end
end
