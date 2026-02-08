Rails.application.routes.draw do
  root "pages#home"
  get "home", to: "pages#home"
  get "theme-preview", to: "pages#theme_preview"

  resources :companies
  resources :offers, only: [:index, :new, :show]
end
