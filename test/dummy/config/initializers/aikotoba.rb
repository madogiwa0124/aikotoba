require 'aikotoba'

Aikotoba.configure do |config|
  config.password_pepper = "aikotoba-default-pepper"
  config.default_scope = {after_sign_in_path: "/sensitives"}
  # config.confirmable = true
  # config.lockable = true
  # config.recoverable = true
  # config.max_failed_attempts = 2

  config.add_scope(:admin, {
    authenticate_for: "Admin",
    session_key: "aikotoba_admin_session_token",
    root_path: "/admin",
    sign_in_path: "/admin/sign_in",
    sign_out_path: "/admin/sign_out",
    sign_up_path: "/admin/sign_up",
    after_sign_in_path: "/admin/sensitives",
    after_sign_out_path: "/admin/sign_in",
    confirm_path: "/admin/confirm",
    unlock_path: "/admin/unlock",
    # NOTE: recover_path is left unset on purpose: the "/recover" it inherits from the
    #       default scope is drawn under root_path, as "/admin/recover".
  })

  # NOTE: Two-factor sign in for trying it out with bin/rails s, in the default scope since
  #       it has a sign up page: sign up at /sign_up, sign in with the emailed code (open it at
  #       /letter_opener), set up the authenticator app from the link on /sensitives, then
  #       sign in again with its code. :email_otp stays in the list since an account without
  #       TOTP couldn't sign in to set it up.
  #       Development only: tests turn it on where they need it.
  if Rails.env.development?
    config.default_scope[:two_factor_strategies] = [:totp, :email_otp]
  end
end
