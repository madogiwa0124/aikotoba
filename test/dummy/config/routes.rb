Rails.application.routes.draw do
  if Rails.env.test?
    post '/test/set-legacy-session', to: 'test_sessions#set_legacy_session'
  end

  mount Aikotoba::Engine => "/"
  get '/sensitives', to: 'sensitives#index'
  get '/admin/sensitives', to: 'admin/sensitives#index'
  get '/api/me', to: 'api/me#show'
  mount LetterOpenerWeb::Engine, at: "/letter_opener" if Rails.env.development?
end
