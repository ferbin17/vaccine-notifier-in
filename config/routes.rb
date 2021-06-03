VaccineNotifier::Engine.routes.draw do
  resources :vaccine_alerts, only: [] do
    collection do
      get 'subscribe'
      post 'subscribe'
      get 'unsubscribe'
      post 'unsubscribe'
    end
  end
  
  root to: "vaccine_alerts#subscribe"
end