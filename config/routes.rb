# Rails.application.routes.draw do
  # devise_for :admin_users
#   devise_for :admin_users, ActiveAdmin::Devise.config
#   ActiveAdmin.routes(self)
#   devise_for :users
#   # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

#   # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
#   # Can be used by load balancers and uptime monitors to verify that the app is live.
#   get "up" => "rails/health#show", as: :rails_health_check

#   # Render dynamic PWA files from app/views/pwa/*
#   get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
#   get "manifest" => "rails/pwa#manifest", as: :pwa_manifest

#   # Defines the root path route ("/")
#   # root "posts#index"
# end

Rails.application.routes.draw do
  require 'sidekiq/web'
  mount Sidekiq::Web => '/sidekiq' # Visit http://localhost:3000/sidekiq

  # Define Devise routes for regular users
  devise_for :users, controllers: {
    registrations: 'admin_registrations'
  }

  # Define Devise routes for admin users
  devise_for :admin_users, ActiveAdmin::Devise.config

  # ActiveAdmin routes
  ActiveAdmin.routes(self)

  # Root redirect to ActiveAdmin login if not logged in
  root to: redirect('/admin')
  get '/admin', to: 'admin#dashboard'
  match 'auth/:provider/callback', to: 'auth/callbacks#create', via: %i[get post]
  # match 'auth/failure', to: redirect('/'), via: %i[get post]

  get '/manifest.json', to: 'pwa#manifest', defaults: { format: 'json' }
end
