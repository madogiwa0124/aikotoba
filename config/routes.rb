Aikotoba::Engine.routes.draw do
  get(Aikotoba.sign_in_path, to: "sessions#new", as: :sign_in)
  post(Aikotoba.sign_in_path, to: "sessions#create")
  get(Aikotoba.sign_up_path, to: "accounts#new", as: :sign_up)
  post(Aikotoba.sign_up_path, to: "accounts#create")
  delete(Aikotoba.sign_out_path, to: "sessions#destroy", as: :sign_out)
end
