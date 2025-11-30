require 'aikotoba'

Aikotoba.password_pepper = "aikotoba-default-pepper"
Aikotoba.sign_in_path = "/sign_in"
Aikotoba.sign_up_path = "/sign_up"
Aikotoba.sign_out_path = "/sign_out"
Aikotoba.after_sign_in_path = "/sensitives"
Aikotoba.after_sign_out_path = "/sign_in"

# Aikotoba.confirmable = true
# Aikotoba.lockable= true
# Aikotoba.recoverable = true
# Aikotoba.max_failed_attempts = 2

Aikotoba.add_namespace(:admin, {
  root_path: "/admin",
  as: "aikotoba_admin",
  session_key: "aikotoba-admin-account-id",
  sign_in_path: "/admin/sign_in",
  sign_out_path: "/admin/sign_out",
  after_sign_in_path: "/admin",
  after_sign_out_path: "/admin/sign_in",
  # for registerable
  registerable: false,
  # for confirmable
  confirmable: false,
  # for lockable
  lockable: true,
  unlock_path: "/admin/unlock",
  max_failed_attempts: 5,
  # for recoverable
  recoverable: true,
  recover_path: "/admin/recover"
})

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
