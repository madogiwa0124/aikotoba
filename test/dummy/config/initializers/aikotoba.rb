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
    recover_path: "/admin/recover",
    # NOTE: magic_link_path is left unset on purpose: the "/magic_link" it inherits from the
    #       default scope is drawn under root_path, as "/admin/magic_link".
  })
end

Rails.application.config.to_prepare do
  Aikotoba::AccountsController.class_eval do
    def after_create_account_process
      user = User.new(nickname: "foo")
      @account.authenticate_target = user
      user.save!
      @account.save!
    end
  end
end
