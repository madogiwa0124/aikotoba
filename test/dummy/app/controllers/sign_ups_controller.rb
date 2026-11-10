# NOTE: The README's "own sign up controller" example (see Registrable), creating a User with
#       the account in one transaction, so the tests can check that the example works.
class SignUpsController < ApplicationController
  def create
    @account = Aikotoba::Account.build_by(attributes: {email: sign_up_params[:email], password: sign_up_params[:password].to_s})
    ActiveRecord::Base.transaction do
      @account.authenticate_target = User.create!(nickname: sign_up_params[:nickname])
      @account.register!
    end
    head :created
  rescue ActiveRecord::RecordInvalid
    head :unprocessable_entity
  end

  private

  def sign_up_params
    params.require(:account).permit(:email, :password, :nickname)
  end
end
