# Vaccine Notifier
gem 'clockwork'
gem 'daemons'
gem 'vaccine_notifier', path: 'vendor/engines/vaccine_notifier'

config.action_mailer.delivery_method = :smtp
config.action_mailer.smtp_settings = {
  address: Rails.application.credentials.aws[:email_configuratons][:address],
  port: Rails.application.credentials.aws[:email_configuratons][:port],
  domain: Rails.application.credentials.aws[:email_configuratons][:domain],
  user_name: Rails.application.credentials.aws[:email_configuratons][:username],
  password: Rails.application.credentials.aws[:email_configuratons][:password],
  authentication: Rails.application.credentials.aws[:email_configuratons][:authentication]
}

mount VaccineNotifier::Engine => "/"
  
yarn add bootstrap@next
yarn add @popperjs/core