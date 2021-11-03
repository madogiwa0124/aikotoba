Rails.application.routes.draw do
  mount Aikotoba::Engine => "/"
  get '/sensitives', to: 'sensitives#index'
end
