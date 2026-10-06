# frozen_string_literal: true

module Aikotoba
  module RequestBackable
    extend ActiveSupport::Concern
    include Authenticatable

    private

    # NOTE: Not session[key] -- deleting makes this single-use, so a stale
    # return_to can't be replayed on a later sign in.
    def return_to_path
      return unless aikotoba_scope_config[:request_back_after_sign_in]
      session.delete(return_to_session_key)
    end

    # NOTE: Only call this from the scope's shared sign-in landing page
    # (SessionsController#new). Calling it from every controller that
    # includes this concern would let bouncing between auth pages (sign in
    # <-> magic link) overwrite the real captured destination.
    def store_return_to_path
      return unless aikotoba_scope_config[:request_back_after_sign_in]
      path = safe_return_to_path_from_referer
      session[return_to_session_key] = path if path
    end

    # NOTE: Store only the same-host path+query, not the full Referer -- a
    # spoofed/foreign Referer can't become an open redirect. Also reject a
    # path starting with "//": URI.parse resolves "http://host//evil/x" as
    # host "host" + path "//evil/x", which is a protocol-relative URL once
    # redirected to -- Rails only started guarding against this in
    # redirect_to itself in 7.1, and this gem supports Rails >= 6.1.4. Also
    # reject this scope's own auth pages, or hopping between them would
    # overwrite the real destination.
    def safe_return_to_path_from_referer
      return if request.referer.blank?
      referer = URI.parse(request.referer)
      # NOTE: blank? covers both a nil path (URI.parse succeeds with no
      # error for an opaque-scheme Referer like "javascript:..." or
      # "mailto:...", leaving #path nil) and a bare-host Referer with no
      # path ("http://host" -> path ""), which would otherwise be stored
      # as-is and defeat the after_sign_in_path fallback.
      return if referer.path.blank?
      safe_referer = -> { !referer.path.start_with?("//") && referer.host == request.host && referer.port == request.port }
      return if !safe_referer.call || aikotoba_own_scoped_path?(referer.path)
      [referer.path, referer.query].compact.join("?")
    rescue URI::InvalidURIError
      nil
    end

    # NOTE: Prefix match, not exact match -- the engine's own confirm/unlock/
    # recover/magic_link flows have a "/:token" sub-page (see config/routes.rb)
    # that a Referer will realistically point at right after that flow
    # completes, not just the bare listed path.
    def aikotoba_own_scoped_path?(path)
      aikotoba_own_scoped_paths.any? { |own_path| path == own_path || path.start_with?("#{own_path}/") }
    end

    # NOTE: Excludes by naming convention (`api_*_path`, `after_*_path`,
    # `root_path`) rather than an enumerated ignore list, so neither a future
    # engine page nor a future host-owned redirect target following the
    # `after_..._path` convention needs this method updated to be handled
    # correctly.
    def aikotoba_own_scoped_paths
      own_scoped_path = ->(key, _) do
        key = key.to_s
        key.end_with?("_path") && key != "root_path" && !key.start_with?("api_", "after_")
      end
      aikotoba_scope_config.select(&own_scoped_path).values.compact
    end

    def return_to_session_key
      "#{aikotoba_session_key}_return_to"
    end
  end
end
