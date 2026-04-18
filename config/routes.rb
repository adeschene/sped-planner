Rails.application.routes.draw do
  get  'login',  to: 'sessions#new', as: :login
  post 'login',  to: 'sessions#create'
  delete 'logout', to: 'sessions#destroy', as: :logout

  root "activities#week"

  get "activities/day", to: "activities#day", as: :day_view
  get "activities/week", to: "activities#week", as: :week_view
  get "activities/month", to: "activities#month", as: :month_view

  resources :activities do
  	resources :notes, shallow: true
  end

  resources :timeslots, only: [:index, :create, :update, :destroy]
end
