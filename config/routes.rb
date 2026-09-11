Rails.application.routes.draw do
  root 'home#index'
  get 'system/status', to: 'system#status', as: :system_status
  get 'up' => 'rails/health#show', as: :rails_health_check
  get 'health/details', to:'curation#health'
  get 'search', to:'entries#index', as: :search
  get 'random', to:'entries#random', as: :random
  get 'hot', to:'entries#index', defaults:{sort:'hot'}, as: :hot
  get 'classics', to:'entries#index', defaults:{sort:'classic'}, as: :classics
  get 'revivals', to:'entries#index', defaults:{sort:'revivals'}, as: :revivals
  get 'timeline', to:'entries#timeline', as: :timeline
  resources :entries, only:[:index,:show], param: :sid do
    post :rate, on: :member
    post :favorite, on: :member
    resources :reports, only:[:new,:create]
  end
  get 'media/:id', to:'media#show', as: :media
  resources :groups, only:[:index,:show,:edit,:update], param: :slug
  resources :transporters, only:[:index,:show], param: :public_id
  resources :trials, only:[:index,:show]
  get 'rankings', to:'rankings#index', as: :rankings
  get 'login', to:'sessions#new', as: :login
  post 'login', to:'sessions#create'
  post 'demo-login', to:'sessions#demo', as: :demo_login
  delete 'logout', to:'sessions#destroy', as: :logout
  get 'signup', to:'users#new', as: :signup
  post 'signup', to:'users#create'
  get 'people/:public_id', to:'users#show', as: :profile
  resources :claims, only:[:index,:create,:show]
  get 'curation', to:'curation#index', as: :curation
  post 'curation/candidates/:id', to:'curation#moderate_candidate', as: :moderate_candidate
  post 'curation/:sid/review', to:'curation#review', as: :review_entry
  post 'curation/:sid/resume', to:'curation#resume_distribution', as: :resume_distribution
  post 'curation/reports/:id', to:'curation#resolve_report', as: :resolve_report
  post 'curation/:sid/merge', to:'curation#merge', as: :merge_entry
  post 'curation/merges/:id/revert', to:'curation#revert', as: :revert_merge
  post 'curation/assets/:id/hide', to:'curation#hide_asset', as: :hide_asset
  post 'curation/assets/:id/redact', to:'curation#redact_asset', as: :redact_asset
  get 'demo', to:'demo#index', as: :demo
  post 'demo/actions', to:'demo#create', as: :demo_actions
  post 'onebot/:connection_id/events', to:'onebot#create', as: :onebot_events
end
