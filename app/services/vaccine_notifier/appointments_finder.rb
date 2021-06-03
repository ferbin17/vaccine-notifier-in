module VaccineNotifier
  class AppointmentsFinder
  
    def initialize
      check_for_data
    end
    
    def check_slots
      fetch_appointments_by_pincode
      fetch_appointments_by_place
    end
    
    def fetch_appointments_by_pincode
      receivers = User.where(state: nil, district: nil)
      receivers.each do |receiver|
        @receiver = receiver
        @url = "#{VaccineNotifier::API_HOST}/appointment/sessions/public/calendarByPin?pincode=#{@receiver.pincode}"
        fetch_appointments
        filter_and_mail
      end
    end
        

    def fetch_appointments_by_place
      receivers = User.where(pincode: nil)
      receivers.each do |receiver|
        @receiver = receiver
        @url = "#{VaccineNotifier::API_HOST}/appointment/sessions/public/calendarByDistrict?district_id=#{receiver.district_id}"
        fetch_appointments
        filter_and_mail
      end
    end
    
    def check_for_data
      State.create_state_records unless State.exists?
      District.create_state_records unless District.exists?
    end
  
    def fetch_appointments
      @appointments = []
      (0..6).each do |n|
        date = (Date.today + n).strftime("%-d-%-m-%Y")
        url = @url + "&date=#{date}"
        @appointments += get_request(url)["centers"]
      end
    end
  
    def filter_and_mail
      filter_appointments
      combine_appointment_sessions
      mail_centre_details unless @apps.empty?
    end
  
    private
      def get_request(url, params = nil)
        begin
          uri = URI.parse(url)
          http = Net::HTTP.new(uri.host, uri.port)
          if uri.scheme == "https"
            http.use_ssl = true
            http.verify_mode = OpenSSL::SSL::VERIFY_NONE
          end
          request = Net::HTTP::Get.new(uri.request_uri, VaccineNotifier::USER_AGENT)
          res = http.request(request)
          if res.code == "200"
            response = JSON.parse(res.body)
            return response
          end
        rescue Exception => r
          p r
          return {}
        end
      end
    
      def filter_appointments
        filter_by_availability
        filter_by_age_limit
        filter_by_fee_type unless @receiver.fee_type.nil?
      end
      
      def filter_by_age_limit
        @apps = @apps.select{|x| !x["sessions"].select{|y| y["min_age_limit"] <= @receiver.age.to_i}.empty?}
      end
      
      def filter_by_pincode
        @apps = @apps.select{|x| x["pincode"].to_s == @receiver.pincode}
      end
      
      def filter_by_fee_type
        fee_type_param = (@receiver.fee_type == "F" ? "Free" : "Paid")
        @apps = @apps.select{|x| x["fee_type"].to_s == fee_type_param}
      end
    
      def filter_by_availability
        @apps = @appointments.each{|x| x["sessions"] = x["sessions"].select{|y| y["available_capacity"] > 0}}
        @apps = @apps.select{|x| !x["sessions"].empty?}
      end
      
      def combine_appointment_sessions
        apps = []
        grouped_appointments = @apps.group_by{|x| x["center_id"]}
        grouped_appointments.keys.each do |key|
          single_appointment = grouped_appointments[key][0]
          grouped_appointments[key]
          (1..(grouped_appointments[key].length - 1)).each do |i|
            single_appointment["sessions"] += grouped_appointments[key][i]["sessions"]
          end
          apps << single_appointment
        end
        @apps = apps
      end
    
      def mail_body
        body = ""
        centre_ids = []
        alert_record = @receiver.vaccine_alerts.find_or_create_by(date: (Date.today).strftime("%-d-%-m-%Y"))
        current_date_notify = alert_record.notified_appointment_ids
        @apps.each do |appointment|
          next if centre_ids.include?(appointment["center_id"]) || current_date_notify.include?(appointment["center_id"])
          centre_details = "Centre Name: #{appointment["name"]}\nBlock Name: #{appointment["block_name"]}\nPincode: #{appointment["pincode"]}\nFrom(Time): #{appointment["from"]}\nTo(Time): #{appointment["to"]}\nType: #{appointment["fee_type"]}\n"
          slot_details = []
          slots = appointment["sessions"].select{|x| x["available_capacity"] > 0}
          session_ids = []
          slots.each do |slot|
            next if session_ids.include?(slot["session_id"])
            slot_details << "Date: #{slot["date"]}\nAvailable: #{slot["available_capacity"]}\nFirst Dose: #{slot["available_capacity_dose1"]}\nSecond Dose: #{slot["available_capacity_dose2"]}\nSlots: #{slot["slots"].join(" , ")}"
            session_ids << slot["session_id"]
          end
          body += centre_details + slot_details.join("\n") + "\n\n"
          centre_ids << appointment["center_id"]
          current_date_notify << appointment["center_id"]
        end
        alert_record.update(notified_appointment_ids: (current_date_notify & @apps.collect{|x| x["center_id"]}))
        body
      end
    
      def mail_centre_details
        body = mail_body
        NotificationMailer.with(receiver: @receiver, body: body).mail_alert.deliver_now if body != ""
      end
    
      def update_notified_list
        notified = YAML.load_file(File.join(File.dirname(__FILE__), '../data/notified.yml'))
        unless notified.nil?  
          single_notified = notified[@email]
          unless single_notified.nil?
            current_date_notify = single_notified[(Date.today).strftime("%-d-%-m-%Y")]
            unless current_date_notify.nil?
              center_ids = @apps.collect{|x| x["center_id"]}
              outstock = current_date_notify - center_ids
              outstock.each do |x|
                current_date_notify.delete(x)
              end
              single_notified[(Date.today).strftime("%-d-%-m-%Y")] = current_date_notify
              notified[@email] = single_notified
              File.open(File.join(File.dirname(__FILE__), '../data/notified.yml'), "w") { |file| file.write(notified.to_yaml) }
            end
          end
        end
      end
      
  end
end