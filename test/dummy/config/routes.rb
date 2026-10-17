Rails.application.routes.draw do
  mount Aikotoba::Engine => "/"
  get '/sensitives', to: 'sensitives#index'
  get '/admin/sensitives', to: 'admin/sensitives#index'
  get '/api/me', to: 'api/me#show'
  mount LetterOpenerWeb::Engine, at: "/letter_opener" if Rails.env.development?
end
