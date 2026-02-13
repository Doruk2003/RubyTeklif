Rails.application.routes.draw do
  get "/login", to: "sessions#new"
  post "/login", to: "sessions#create"
  delete "/logout", to: "sessions#destroy"
  get "/password-recovery", to: "sessions#recovery"
  post "/password-recovery", to: "sessions#send_recovery"

  namespace :admin do
    resources :users, only: [:index, :new, :create, :edit, :update] do
      member do
        patch :disable
        patch :enable
        post :reset_password
      end
    end
    resources :activity_logs, only: [:index]
  end

  root "pages#home"
  get "home", to: "pages#home"
  get "theme-preview", to: "pages#theme_preview"

  resources :companies
  resources :offers, only: [:index, :new, :create, :show]
  resources :products, only: [:index, :new, :create, :show, :edit, :update, :destroy]
  resources :currencies, only: [:index, :new, :create, :edit, :update, :destroy]
  resources :categories, only: [:index, :new, :create]
end
