require 'net/http'
require 'uri'
require "cgi"
require 'json'
require 'date'
require 'mail'
require 'yaml'
require 'logger'

class VaccineNotifier
  @@host = "https://cdn-api.co-vin.in/api/v2"
  
  def initialize(email, state, district, age, pincode = nil, fee_type = nil)
    @email = email
    @state = state
    @district = district
    @age = age.to_i
    @pincode = pincode
    @fee_type = fee_type
  end
  
  def perform
    check_for_last_run
    fetch_states
    fetch_districts
    fetch_appointments
    filter_appointments
    combine_appointment_sessions
    mail_centre_details unless @appointments.empty?
    update_notified_list
  end
  
  def fetch_states
    url = "#{@@host}/admin/location/states"
    states = get_request(url)["states"]
    @state_record = states.select{|x| x["state_name"].downcase == @state.downcase}.first
  end
  
  def fetch_districts
    url = "#{@@host}/admin/location/districts/#{@state_record["state_id"]}"
    districts = get_request(url)["districts"]
    @district_record = districts.select{|x| x["district_name"].downcase == @district.downcase}.first
  end
  
  def fetch_appointments
    @appointments = []
    (0..6).each do |n|
      date = (Date.today + n).strftime("%-d-%-m-%Y")
      url = "#{@@host}/appointment/sessions/public/calendarByDistrict?district_id=#{@district_record["district_id"]}&date=#{date}"
      @appointments += get_request(url)["centers"]
    end
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
        request = Net::HTTP::Get.new(uri.request_uri)
        res = http.request(request)
        if res.code == "200"
          response = JSON.parse(res.body)
          return response
        end
      rescue Exception => r
      end
    end
    
    def filter_appointments
      filter_by_pincode unless @pincode.nil?
      filter_by_fee_type unless @fee_type.nil?
      filter_by_availability
      filter_by_age_limit
    end
    
    def filter_by_age_limit
      @appointments = @appointments.select{|x| !x["sessions"].select{|y| y["min_age_limit"] <= @age}.empty?}
    end
    
    def filter_by_pincode
      @appointments = @appointments.select{|x| x["pincode"].to_s == @pincode}
    end
    
    def filter_by_fee_type
      fee_type_param = (@fee_type == "F" ? "Free" : "Paid")
      @appointments = @appointments.select{|x| x["fee_type"].to_s == fee_type_param}
    end
    
    def filter_by_availability
      @appointments = @appointments.select{|x| !x["sessions"].select{|y| y["available_capacity"] > 0}.empty?}
    end
    
    def combine_appointment_sessions
      apps = []
      grouped_appointments = @appointments.group_by{|x| x["center_id"]}
      grouped_appointments.keys.each do |key|
        single_appointment = grouped_appointments[key][0]
        grouped_appointments[key]
        (1..(grouped_appointments[key].length - 1)).each do |i|
          single_appointment["sessions"] += grouped_appointments[key][i]["sessions"]
        end
        apps << single_appointment
      end
      @appointments = apps
    end
    
    def construct_mail_body
      body = ""
      centre_ids = []
      notified = YAML.load_file(File.join(File.dirname(__FILE__), '../data/notified.yml'))||{}
      single_notified = notified[@email]||{}
      current_date_notify = single_notified[(Date.today).strftime("%-d-%-m-%Y")]||[]
      @appointments.each do |appointment|
        next if centre_ids.include?(appointment["center_id"]) || current_date_notify.include?(appointment["center_id"])
        centre_details = "Centre Name: #{appointment["name"]}\nBlock Name: #{appointment["block_name"]}\nPincode: #{appointment["pincode"]}\nFrom(Time): #{appointment["from"]}\nTo(Time): #{appointment["to"]}\nType: #{appointment["fee_type"]}\n"
        slot_details = []
        slots = appointment["sessions"].select{|x| x["available_capacity"] > 0}
        slots = appointment["sessions"]
        session_ids = []
        slots.each do |slot|
          next if session_ids.include?(slot["session_id"])
          slot_details << "Date: #{slot["date"]}\nAvailable: #{slot["available_capacity"]}\nSlots: #{slot["slots"].join(" , ")}"
          session_ids << slot["session_id"]
        end
        body += centre_details + slot_details.join("\n") + "\n\n"
        centre_ids << appointment["center_id"]
        current_date_notify << appointment["center_id"]
      end
      single_notified[(Date.today).strftime("%-d-%-m-%Y")] = current_date_notify
      notified[@email] = single_notified
      File.open(File.join(File.dirname(__FILE__), '../data/notified.yml'), "w") { |file| file.write(notified.to_yaml) }
      body
    end
    
    def mail_centre_details
      body = construct_mail_body
      if body != ""
        begin
          email = @email
          options = {address: "smtp.gmail.com", port: 587, user_name: 'example@gmail.com',
            password: 'example', authentication: 'plain', enable_starttls_auto: true}
          Mail.defaults do
            delivery_method :smtp, options
          end

          Mail.deliver do
            to email
            from 'productsmf@gmail.com'
            subject 'Vaccine Alert'
            body body
          end
        rescue Exception => r
        end
      end
    end
    
    def check_for_last_run
      if File.exists?(File.join(File.dirname(__FILE__), '../data/time.txt'))
        file_data = File.open(File.join(File.dirname(__FILE__), '../data/time.txt')).read
        last_time = file_data.to_i
        current_time = Time.now.to_i
        diff = current_time - last_time
        if diff < 60
          sleep(60 - diff)
        end
      end
    end
    
    
    def update_notified_list
      notified = YAML.load_file(File.join(File.dirname(__FILE__), '../data/notified.yml'))
      unless notified.nil?
        single_notified = notified[@email]
        unless single_notified.nil?
          current_date_notify = single_notified[(Date.today).strftime("%-d-%-m-%Y")]
          unless current_date_notify.nil?
            center_ids = @appointments.collect{|x| x["center_id"]}
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