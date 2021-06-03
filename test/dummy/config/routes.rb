Rails.application.routes.draw do
  mount VaccineNotifier::Engine => "/vaccine_notifier"
end
