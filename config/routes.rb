Rails.application.routes.draw do
  root "locations#index"
  get "/location", to: "locations#show", as: :location
end
