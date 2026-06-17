Rails.application.routes.draw do
  mount RailsIcons::Engine, at: '/rails_icons'
  devise_for :users

  root "pages#home"

  get "chris", to: "pages#chris"
  get "projects", to: "pages#projects"
  get "updates", to: "pages#news", as: :updates
  get "funds", to: "pages#funds"
  get "zero-waste", to: "pages#zero_waste", as: :zero_waste
  get "news", to: "pages#news"

  # Keep old routes working
  get "bio", to: redirect("/chris")

  resources :tributes, only: [ :index, :new, :create, :show ]
  resources :memories, only: [ :index, :new, :create, :show ], path: "timeline" do
    resources :replies, only: [ :create ]
  end
  resources :trees, only: [ :index, :new, :create, :show ]
  resources :recipes, only: [ :index, :new, :create, :show ]
  resources :photo_submissions, only: [ :new, :create ], path: "submit-photos"
  resources :newsletter_subscribers, only: [ :create ]
  resources :events, only: [ :index, :show ]
  resources :bee_hives, only: [ :index, :new, :create, :show ]
  get "map", to: "map#index", as: :map

  namespace :admin do
    root "dashboard#index"
    resources :tributes, only: [ :index, :show, :update, :destroy ]
    resources :memories, only: [ :index, :show, :update, :destroy ]
    resources :trees, only: [ :index, :show, :update, :destroy ]
    resources :recipes, only: [ :index, :show, :update, :destroy ]
    resources :photo_submissions, only: [ :index, :show, :update, :destroy ]
    resources :gallery_photos
    resources :events
    resources :bee_hives, only: [ :index, :show, :edit, :update, :destroy ]
  end

  if Rails.env.development? || Rails.env.test?
    get "style-guide", to: "pages#style_guide", as: :style_guide
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
