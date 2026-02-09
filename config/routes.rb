Rails.application.routes.draw do
  root "pages#home"
  get "home", to: "pages#home"
  get "theme-preview", to: "pages#theme_preview"

  resources :companies
  resources :offers, only: [:index, :new, :show]
  resources :products, only: [:index, :new, :create, :show, :edit, :update, :destroy]
  resources :currencies, only: [:index, :new, :create, :edit, :update, :destroy]
end
