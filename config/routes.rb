# frozen_string_literal: true

require "aikotoba/constraints/registerable_constraint"
require "aikotoba/constraints/confirmable_constraint"
require "aikotoba/constraints/lockable_constraint"
require "aikotoba/constraints/recoverable_constraint"

Aikotoba::Engine.routes.draw do
  get(Aikotoba.sign_in_path, to: "sessions#new", as: :sign_in)
  post(Aikotoba.sign_in_path, to: "sessions#create")
  delete(Aikotoba.sign_out_path, to: "sessions#destroy", as: :sign_out)
  constraints(Aikotoba::RegisterableConstraint) do
    get(Aikotoba.sign_up_path, to: "accounts#new", as: :registerable_new)
    post(Aikotoba.sign_up_path, to: "accounts#create", as: :registerable_create)
  end
  constraints(Aikotoba::ConfirmableConstraint) do
    get(Aikotoba.confirm_path, to: "confirms#new", as: :confirmable_new)
    post(Aikotoba.confirm_path, to: "confirms#create", as: :confirmable_create)
    get(File.join(Aikotoba.confirm_path, ":token"), to: "confirms#update", as: :confirmable_confirm)
  end
  constraints(Aikotoba::LockableConstraint) do
    get(Aikotoba.unlock_path, to: "unlocks#new", as: :lockable_new)
    post(Aikotoba.unlock_path, to: "unlocks#create", as: :lockable_create)
    get(File.join(Aikotoba.unlock_path, ":token"), to: "unlocks#update", as: :lockable_unlock)
  end
  constraints(Aikotoba::RecoverableConstraint) do
    get(Aikotoba.recover_path, to: "recoveries#new", as: :recoverable_new)
    post(Aikotoba.recover_path, to: "recoveries#create", as: :recoverable_create)
    get(File.join(Aikotoba.recover_path, ":token"), to: "recoveries#edit", as: :recoverable_edit)
    patch(File.join(Aikotoba.recover_path, ":token"), to: "recoveries#update", as: :recoverable_update)
  end
end
