Rails.application.routes.draw do
  mount RailsIcons::Engine, at: "/rails_icons"
  devise_for :users

  root "pages#home"

  get "chris", to: "pages#chris"
  get "projects", to: "pages#projects"
  get "updates", to: "pages#news", as: :updates
  get "funds", to: redirect("/projects#funds"), as: :funds
  get "zero-waste", to: "pages#zero_waste", as: :zero_waste
  get "news", to: "pages#news"

  # Keep old routes working
  get "bio", to: redirect("/chris")
  get "trees", to: redirect("/projects#trees")

  resources :tributes, only: [ :index, :new, :create, :show, :edit, :update ]
  resources :memories, only: [ :index, :new, :create, :show ], path: "timeline" do
    resources :replies, only: [ :create ]
  end
  resources :trees, only: [ :new, :create, :show ]
  resources :recipes, only: [ :index, :new, :create, :show ]
  get "gallery", to: "gallery#index", as: :gallery
  get "submit-photos", to: "gallery#new", as: :submit_photos
  post "submit-photos", to: "gallery#create"
  resources :newsletter_subscribers, only: [ :create ]
  resources :events, only: [ :index, :show ]
  resources :bee_hives, only: [ :index, :new, :create, :show ]
  get "map", to: "map#index", as: :map

  namespace :admin do
    root "dashboard#index"
    resources :tributes, only: [ :index, :new, :create, :show, :edit, :update, :destroy ]
    resources :memories, only: [ :index, :new, :create, :show, :edit, :update, :destroy ]
    resources :milestones, only: [ :index, :new, :create, :edit, :update, :destroy ]
    resources :trees, only: [ :index, :new, :create, :show, :edit, :update, :destroy ]
    resources :recipes, only: [ :index, :new, :create, :show, :edit, :update, :destroy ]
    resources :gallery_photos
    resources :events
    resources :bee_hives, only: [ :index, :new, :create, :show, :edit, :update, :destroy ]
    resources :users, only: [ :index, :update ]
    resources :newsletter_subscribers, only: [ :index, :destroy ]
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
