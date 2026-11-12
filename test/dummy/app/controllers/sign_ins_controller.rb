# NOTE: The README's "own sign in controller" example (see TwoFactorAuthenticatable), so the
#       tests can check that it works with and without a code. Keep the two in step.
class SignInsController < ApplicationController
  def create
    account = Aikotoba::Account::PasswordHash.authenticate_by(
      attributes: {email: params[:email], password: params[:password]},
      target_type_name: Aikotoba.default_scope.authenticate_for,
      reset_failed_attempts: !aikotoba_two_factor_required?
    )
    return head(:unprocessable_entity) unless account

    if aikotoba_begin_sign_in(account)
      redirect_to "/sensitives"
    else
      redirect_to aikotoba.new_two_factor_path
    end
  end
end
