require 'aikotoba'

Aikotoba.authenticate_account_method = "current_account"
Aikotoba.prevent_timing_atack = false
Aikotoba.password_pepper = "aikotoba-default-pepper"
Aikotoba.password_stretch = 3
Aikotoba.sign_in_path = "/sign_in"
Aikotoba.sign_up_path = "/sign_up"
Aikotoba.sign_out_path = "/sign_out"
Aikotoba.after_sign_in_path = "/sensitives"
Aikotoba.after_sign_out_path = "/sign_in"

# Aikotoba.confirmable = true
# Aikotoba.lockable= true
# Aikotoba.recoverable = true

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
