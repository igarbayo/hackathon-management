Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api do
    namespace :v1 do
      get "csrf", to: "csrf#show"

      namespace :auth do
        post "signup", to: "registrations#create"
        post "login", to: "sessions#create"
        post "logout", to: "sessions#destroy"
        get "github", to: "github#new"
        get "github/callback", to: "github#callback"
        get "google", to: "google#new"
        get "google/callback", to: "google#callback"
      end

      get "token", to: "token_introspection#show"

      get "me", to: "me#show"
      patch "me", to: "me#update"
      delete "me", to: "me#destroy"
      delete "me/identities/:provider", to: "me#destroy_identity"

      post "webhooks/github", to: "/webhooks/github#create"
      get "github/setup", to: "github_setup#show"

      post "cli/device", to: "cli/device#create"
      post "cli/device/token", to: "cli/device#token"
      get "cli/config", to: "cli/config#show"
      patch "cli/me", to: "cli/me#update"
      delete "cli/me", to: "cli/me#destroy"
      post "ingest/claude_code", to: "ingest/claude_code#create"

      resources :teams, only: %i[create show update destroy] do
        post "code/rotate", to: "teams#rotate_code"

        resources :members, only: %i[index update destroy], controller: "team_members"
        resources :objectives, only: %i[index create update destroy]

        resources :features, only: %i[index show create update destroy], param: :key do
          post :move, on: :member

          resources :arguments, only: %i[create update destroy] do
            put :vote, on: :member
            delete :vote, on: :member
          end
        end

        resources :milestones, only: %i[index create update destroy]
        resources :tokens, only: %i[index create destroy]
        resources :integrations, only: %i[index create destroy]

        resources :webhooks, only: %i[index create update destroy] do
          post :test, on: :member
          post :rotate_secret, on: :member
          get :deliveries, on: :member
          post "deliveries/:delivery_id/redeliver", on: :member, action: :redeliver
        end
        get "timeline", to: "timeline#show"

        resources :analyses, only: %i[index show create] do
          get :latest, on: :collection
        end

        get "github/install_url", to: "github#install_url"
        get "github/available_repos", to: "github#available_repos"
        resources :repositories, only: %i[index create destroy] do
          post :resync, on: :member
        end

        post "cli/device/approve", to: "cli/device_approvals#approve"
        post "cli/device/deny", to: "cli/device_approvals#deny"
        patch "me/claude_code", to: "claude_code#update"
        delete "me/claude_code", to: "claude_code#destroy"

        get "activity", to: "activity#index"
        get "activity/summary", to: "activity#summary"
        post "activity/attribution/bulk", to: "activity_attributions#bulk"
        post "activity/:event_id/attribution", to: "activity_attributions#create"

        collection do
          post :join
        end
      end
    end
  end
end
