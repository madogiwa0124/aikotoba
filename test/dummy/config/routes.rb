Rails.application.routes.draw do
  mount Aikotoba::Engine => "/"
  get '/sensitives', to: 'sensitives#index'
  mount LetterOpenerWeb::Engine, at: "/letter_opener" if Rails.env.development?
end
