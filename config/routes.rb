Rails.application.routes.draw do
  require "sidekiq/web"

  # Define Devise routes for regular users (signup disabled)
  devise_for :users, skip: :registrations

  # Restrict queue operations to authenticated application users.
  authenticate :user do
    mount Sidekiq::Web => "/sidekiq"
  end

  # Define Devise routes for admin users (signup disabled)
  devise_for :admin_users, ActiveAdmin::Devise.config

  # ActiveAdmin routes
  ActiveAdmin.routes(self)

  # Send every user through the shared ActiveAdmin entry point without a cacheable redirect.
  root to: redirect("/admin", status: 302)
  get "/admin", to: "admin#dashboard"
  match "auth/:provider/callback", to: "auth/callbacks#create", via: %i[get post]
  # match "auth/failure", to: redirect("/"), via: %i[get post]

  get "/manifest.json", to: "pwa#manifest", defaults: { format: "json" }
end
