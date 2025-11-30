Rails.application.routes.draw do
  Aikotoba.namespaces.each do |name, config|
    scope config[:root_path] do
      mount Aikotoba::Engine => "/", as: config[:as]
    end
  end

  get '/sensitives', to: 'sensitives#index'
  mount LetterOpenerWeb::Engine, at: "/letter_opener" if Rails.env.development?
end
