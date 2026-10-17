# frozen_string_literal: true

module Aikotoba
  module RequestBackable
    extend ActiveSupport::Concern
    include Scopable

    # NOTE: Modeled on the Rails authentication generator's
    # `request_authentication` / `after_authentication_url` pair. Call this
    # from the host app's own `authenticate_account!`-style before_action
    # instead of a bare `redirect_to` to the sign in page. The engine can't
    # capture the destination on its own: the host owns that redirect, and the
    # `Referer` the browser sends to `GET /sign_in` is the page that *linked*
    # to the protected page, not the protected page itself (a redirect never
    # updates the Referer).
    def aikotoba_request_authentication(**redirect_options)
      aikotoba_store_return_to_path
      redirect_to aikotoba_scoped_path(:new_session_path), **redirect_options
    end

    private

    # NOTE: Not session[key] -- deleting makes this single-use, so a stale
    # return_to can't be replayed on a later sign in.
    def aikotoba_after_authentication_path
      session.delete(aikotoba_return_to_session_key) || aikotoba_scope_config[:after_sign_in_path]
    end

    # NOTE: Unlike the Rails generator, which stores `request.url`, store only
    # the host-less `fullpath`, so the stored value can never point at
    # another host.
    def aikotoba_store_return_to_path
      path = request.fullpath
      session[aikotoba_return_to_session_key] = path if aikotoba_storable_return_to_path?(path)
    end

    # NOTE: Only a page the browser can be sent back to with a plain GET is
    # stored -- redirecting back to a POST/XHR/JSON endpoint after sign in
    # would replay it as a GET and fail. `fullpath` never carries a host, but
    # a request for "//evil.example.com/x" (or "/\evil.example.com/x", which
    # browsers treat the same) still yields a protocol-relative URL once
    # redirected to -- Rails only started guarding against this in
    # redirect_to itself in 7.1, and this gem supports Rails >= 6.1.4.
    def aikotoba_storable_return_to_path?(path)
      return false unless request.get? && !request.xhr? && request.format.html?
      path.start_with?("/") && !path.start_with?("//", "/\\")
    end

    def aikotoba_return_to_session_key
      "#{aikotoba_scope_config[:session_key]}_return_to_after_authenticating"
    end
  end
end
