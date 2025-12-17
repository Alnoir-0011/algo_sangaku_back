Rails.application.routes.draw do
  if Rails.env.development?
    mount MissionControl::Jobs::Engine, at: "/jobs"
  end
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Defines the root path route ("/")
  # root "posts#index"
  namespace :api, format: :json do
    namespace :v1 do
      resource :authenticate, only: %i[create destroy]
      resources :sangakus, only: %i[index show] do
        resource :save, only: %i[create], controller: "sangaku_saves"
      end
      resources :shrines, only: %i[index show] do
        resources :sangakus, only: %i[index], controller: "shrines_sangakus"
      end

      namespace :user do
        resources :sangakus, only: %i[index show create update destroy], shallow: true do
          resource :result, only: %i[show]
          resource :dedicate, only: %i[create]
          resources :answers, only: %i[create show]
        end
        resources :answer_results, only: %i[show]
        resources :saved_sangakus, only: %i[index show] do
          get "answer", on: :member
        end
        resource :profile, only: %i[update]
      end
    end
  end
end
