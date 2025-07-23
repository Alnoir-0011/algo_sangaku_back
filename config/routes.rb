Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Defines the root path route ("/")
  # root "posts#index"
  namespace :api, format: :json do
    namespace :v1 do
      resources :users, only: %i[create]
      resources :shrines, only: %i[index]
      resources :sangakus, only: %i[create]

      namespace :user do
        resources :sangakus, only: %i[index]
      end
    end
  end
end
