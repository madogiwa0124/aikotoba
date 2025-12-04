# frozen_string_literal: true

require "aikotoba/constraints/registerable_constraint"
require "aikotoba/constraints/confirmable_constraint"
require "aikotoba/constraints/lockable_constraint"
require "aikotoba/constraints/recoverable_constraint"

Aikotoba::Engine.routes.draw do
  Aikotoba.scopes.each do |scope_name, config|
    scope as: ((scope_name == "default") ? nil : scope_name) do
      get(config[:sign_in_path], to: "sessions#new", as: :new_session)
      post(config[:sign_in_path], to: "sessions#create", as: :create_session)
      delete(config[:sign_out_path], to: "sessions#destroy", as: :destroy_session)

      constraints(Aikotoba::RegisterableConstraint) do
        get(config[:sign_up_path], to: "accounts#new", as: :new_account)
        post(config[:sign_up_path], to: "accounts#create", as: :create_account)
      end

      constraints(Aikotoba::ConfirmableConstraint) do
        get(config[:confirm_path], to: "confirms#new", as: :new_confirmation_token)
        post(config[:confirm_path], to: "confirms#create", as: :create_confirmation_token)
        get(File.join(config[:confirm_path], ":token"), to: "confirms#update", as: :confirm_account)
      end

      constraints(Aikotoba::LockableConstraint) do
        get(config[:unlock_path], to: "unlocks#new", as: :new_unlock_token)
        post(config[:unlock_path], to: "unlocks#create", as: :create_unlock_token)
        get(File.join(config[:unlock_path], ":token"), to: "unlocks#update", as: :unlock_account)
      end

      constraints(Aikotoba::RecoverableConstraint) do
        get(config[:recover_path], to: "recoveries#new", as: :new_recovery_token)
        post(config[:recover_path], to: "recoveries#create", as: :create_recovery_token)
        get(File.join(config[:recover_path], ":token"), to: "recoveries#edit", as: :edit_account_password)
        patch(File.join(config[:recover_path], ":token"), to: "recoveries#update", as: :update_account_password)
      end
    end
  end
end
