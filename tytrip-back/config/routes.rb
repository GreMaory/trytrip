Rails.application.routes.draw do
  # Liveness probe for load balancers: 200 if the app boots, no internal details.
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api, defaults: { format: :json } do
    namespace :v1 do
      # --- Authentication & account (any host) ---
      get "csrf" => "csrf#show"
      resource :session, only: %i[create destroy] do
        post :mfa, action: :verify_mfa
      end
      resource :signup, only: :create
      resource :password_reset, only: %i[create update]
      resource :email_verification, only: %i[create update]
      resource :invitation_acceptance, only: %i[show create]

      resource :me, controller: "me", only: %i[show update]
      namespace :me do
        resource :password, only: :update
        resources :sessions, only: %i[index destroy] do
          delete :others, on: :collection, action: :destroy_others
        end
        resource :mfa, only: %i[create update destroy] do
          post :recovery_codes
        end
      end

      # --- Current organization (tenant subdomain) ---
      resource :organization, only: %i[show update]
      resources :organizations, only: :create
      resources :memberships, only: %i[index update destroy]
      resources :roles
      resources :permissions, only: :index
      resources :invitations, only: %i[index create destroy]
      resources :audit_events, only: :index

      # --- PMS (current organization) ---
      resource :dashboard, only: :show
      resource :calendar, only: :show
      resources :properties
      resources :units, only: %i[index create update destroy]
      resources :guests
      resources :reservations, only: %i[index show create update] do
        post :transition, on: :member
      end
      resources :availability_blocks, only: %i[create destroy]

      # --- Platform administration ---
      namespace :admin do
        resources :tenants, only: %i[index show create update] do
          member do
            post :suspend
            post :activate
          end
        end
        resources :users, only: %i[index show] do
          member do
            post :suspend
            post :activate
            post :revoke_sessions
          end
        end
        resources :audit_events, only: :index
      end
    end
  end
end
