Rails.application.routes.draw do
  mount Aikotoba::Engine => "/"
  get '/sensitives', to: 'sensitives#index'
  get '/admin/sensitives', to: 'admin/sensitives#index'
  delete '/custom_sign_out', to: 'sign_outs#destroy'
  post '/custom_sign_up', to: 'sign_ups#create'
  mount LetterOpenerWeb::Engine, at: "/letter_opener" if Rails.env.development?
end
