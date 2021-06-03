module VaccineNotifier
  class NotificationMailer < ApplicationMailer
    default from: 'productsmf@gmail.com'
    
    def mail_alert
      @receiver = params[:receiver]
      @body = params[:body]
      mail(to: @receiver.email, subject: 'Vaccine Alert')
    end
  end
end
