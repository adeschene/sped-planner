Rails.application.routes.draw do
  root "activities#week"

  get "activities/day", to: "activities#day", as: :day_view
  get "activities/week", to: "activities#week", as: :week_view
  get "activities/month", to: "activities#month", as: :month_view

  resources :activities
end
