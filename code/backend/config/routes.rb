Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Defines the root path route ("/")
  # root "posts#index"

  # /api/ の下の、ここより上のどれにも当てはまらない URL は、404 の形で返す（API設計.md の 16-1-10）。
  # 上から順に当てはめるので、この行は必ずいちばん最後に置く
  match "api/*path", to: "errors#not_found", via: :all
end
