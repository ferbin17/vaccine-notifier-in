require 'net/http'
require 'uri'
require "cgi"
require 'json'
require 'yaml'
require_relative 'state'

class District
  @@host = "https://cdn-api.co-vin.in/api/v2"

  def fetch_and_save_data
    fetch_states
    districts = {}
    @states.each do |state|
      districts[state["state_id"]] = fetch_data(state["state_id"])
    end
    @districts = {"districts" => districts}
    save_data
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
    
    def fetch_states
      if File.exists?(File.join(File.dirname(__FILE__), '../data/states.yml'))
        @states = YAML.load_file(File.join(File.dirname(__FILE__), '../data/states.yml'))["states"]
      else
        State.new.fetch_and_save_data
        fetch_states
      end
    end
    
    def fetch_data(state_id)
      url = "#{@@host}/admin/location/districts/#{state_id}"
      districts = get_request(url)["districts"]
      districts
    end
    
    def save_data
      File.open(File.join(File.dirname(__FILE__), '../data/districts.yml'), "w") { |file| 
        file.write(@districts.to_yaml) 
      }
    end
end