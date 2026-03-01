Rails.application.routes.draw do
  get "/login", to: "sessions#new"
  post "/login", to: "sessions#create"
  delete "/logout", to: "sessions#destroy"
  get "/password-recovery", to: "sessions#recovery"
  post "/password-recovery", to: "sessions#send_recovery"

  namespace :admin do
    resources :users, only: [:index, :new, :create, :edit, :update] do
      collection do
        post :export
        get "exports/:token", action: :download_export, as: :download_export
      end
      member do
        patch :disable
        patch :enable
        post :reset_password
      end
    end
    resources :activity_logs, only: [:index] do
      collection do
        post :export
        get "exports/:token", action: :download_export, as: :download_export
      end
    end
  end

  root "pages#home"
  get "home", to: "pages#home"
  get "ajanda", to: "pages#ajanda"
  resources :calendar_events, only: [:index, :create, :update, :destroy]

  resources :companies do
    collection { get :options }
    member { patch :restore }
  end
  namespace :offers do
    resources :standart do
      member do
        patch :restore
      end
    end
    resources :demonte
    resources :montaj
  end
  resources :products, only: [:index, :new, :create, :show, :edit, :update, :destroy] do
    member do
      patch :restore
      delete "images/:image_id", action: :destroy_image, as: :destroy_image
      patch "images/:image_id/move", action: :move_image, as: :move_image
    end
  end
  resources :currencies, only: [:index, :new, :create, :edit, :update, :destroy] do
    member do
      patch :restore
    end
  end
  resources :categories, only: [:index, :new, :create, :edit, :update, :destroy] do
    member do
      patch :restore
    end
  end
  resources :brands, only: [:new, :create]
end
