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

      get "me", to: "me#show"
      patch "me", to: "me#update"
      delete "me", to: "me#destroy"
      delete "me/identities/:provider", to: "me#destroy_identity"

      post "webhooks/github", to: "/webhooks/github#create"
      get "github/setup", to: "github_setup#show"

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
        get "timeline", to: "timeline#show"

        resources :analyses, only: %i[index show create] do
          get :latest, on: :collection
        end

        get "github/install_url", to: "github#install_url"
        get "github/available_repos", to: "github#available_repos"
        resources :repositories, only: %i[index create destroy] do
          post :resync, on: :member
        end

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
