require 'aikotoba'

Aikotoba.authenticate_account_method = "current_user"
Aikotoba.authorize_account_method = "authenticate_user!"
Aikotoba.prevent_timing_atack = false
Aikotoba.password_papper = "aikotoba-default-pepper"
Aikotoba.password_stretch = 3
Aikotoba.sign_in_path = "/sign_in"
Aikotoba.sign_up_path = "/sign_up"
Aikotoba.sign_out_path = "/sign_out"
Aikotoba.after_sign_in_path = "/sensitives"
Aikotoba.failed_sign_in_path = "/sign_in"
Aikotoba.after_sign_up_path = "/sign_in"
Aikotoba.after_sign_out_path = "/sign_in"
Aikotoba.appeal_sign_in_path = "/sign_in"

Aikotoba.enable_confirm = true

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
