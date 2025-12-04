require 'aikotoba'

Aikotoba.password_pepper = "aikotoba-default-pepper"
Aikotoba.default_scope = {after_sign_in_path: "/sensitives"}
# Aikotoba.after_sign_in_path = "/sensitives"
# Aikotoba.confirmable = true
# Aikotoba.lockable= true
# Aikotoba.recoverable = true
# Aikotoba.max_failed_attempts = 2

Aikotoba.add_scope(:admin, {
  authenticate_for: "Admin",
  session_key: "aikotoba-admin-account-id",
  root_path: "/admin",
  sign_in_path: "/admin/sign_in",
  sign_out_path: "/admin/sign_out",
  sign_up_path: "/admin/sign_up",
  after_sign_in_path: "/admin/sensitives",
  after_sign_out_path: "/admin/sign_in",
  confirm_path: "/admin/confirm",
  unlock_path: "/admin/unlock",
  recover_path: "/admin/recover"
})

Rails.application.config.to_prepare do
  Aikotoba::AccountsController.class_eval do
    def after_create_account_process
      if aikotoba_scope.admin?
        admin = Admin.new(nickname: "admin_foo")
        @account.authenticate_target = admin
        admin.save!
      else
        user = User.new(nickname: "foo")
        @account.authenticate_target = user
        user.save!
      end
      @account.save!
    end
  end
end
