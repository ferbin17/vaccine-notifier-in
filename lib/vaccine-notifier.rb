require 'net/http'
require 'uri'
require "cgi"
require 'json'
require 'date'
require 'mail'
require 'yaml'
require 'logger'
require_relative 'state'
require_relative 'district'

class VaccineNotifier
  @@host = "https://cdn-api.co-vin.in/api/v2"
  
  def check_slots
    check_for_last_run
    fetch_receivers
    group_receivers_and_mail
  end
  
  def fetch_receivers
    receivers_data = YAML.load_file(File.join(File.dirname(__FILE__), '../data/notify.yml'))["receivers"]
    @receivers = receivers_data.map{|x| x.split(", ")}
  end
  
  def group_receivers_and_mail
    state_grouped_receivers = @receivers.group_by{|x| x[1]}
    state_grouped_receivers.each do |key1, value1|
      @state = key1
      districts_grouped_receivers = value1.group_by{|x| x[2]}
      districts_grouped_receivers.each do |key2, value2|
        @district = key2
        fetch_states
        unless @state_record.nil?
          fetch_districts
          unless @district_record.nil?
            fetch_appointments
            value2.each do |x|
              @email, @age, @pincode, @fee_type = x[0], x[3].to_i, x[4], x[5]
              filter_and_mail
            end
          end
        end
      end
    end
  end
  
  def fetch_states
    if File.exists?(File.join(File.dirname(__FILE__), '../data/states.yml'))
      states = YAML.load_file(File.join(File.dirname(__FILE__), '../data/states.yml'))["states"]
    else
      State.new.fetch_and_save_data
      fetch_states
    end
    @state_record = states.select{|x| x["state_name"].downcase == @state.downcase }.first 
  end
  
  def fetch_districts
    if File.exists?(File.join(File.dirname(__FILE__), '../data/districts.yml'))
      districts = YAML.load_file(File.join(File.dirname(__FILE__), '../data/districts.yml'))["districts"][@state_record["state_id"]]
    else
      District.new.fetch_and_save_data
      fetch_districts
    end
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
  
  def filter_and_mail
    filter_appointments
    combine_appointment_sessions
    mail_centre_details unless @apps.empty?
    update_notified_list
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
        p r
      end
    end
    
    def filter_appointments
      filter_by_availability
      filter_by_age_limit
      filter_by_pincode unless @pincode.nil?
      filter_by_fee_type unless @fee_type.nil?
    end
    
    def filter_by_age_limit
      @apps = @apps.select{|x| !x["sessions"].select{|y| y["min_age_limit"] <= @age}.empty?}
    end
    
    def filter_by_pincode
      @apps = @apps.select{|x| x["pincode"].to_s == @pincode}
    end
    
    def filter_by_fee_type
      fee_type_param = (@fee_type == "F" ? "Free" : "Paid")
      @apps = @apss.select{|x| x["fee_type"].to_s == fee_type_param}
    end
    
    def filter_by_availability
      @apps = @appointments.select{|x| !x["sessions"].select{|y| y["available_capacity"] > 0}.empty?}
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
    
    def construct_mail_body
      body = ""
      centre_ids = []
      notified = YAML.load_file(File.join(File.dirname(__FILE__), '../data/notified.yml'))||{}
      single_notified = notified[@email]||{}
      current_date_notify = single_notified[(Date.today).strftime("%-d-%-m-%Y")]||[]
      @apps.each do |appointment|
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
          p r
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