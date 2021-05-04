require 'net/http'
require 'uri'
require "cgi"
require 'json'
require 'yaml'

class State
  @@host = "https://cdn-api.co-vin.in/api/v2"

  def fetch_and_save_data
    fetch_data
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
    
    def fetch_data
      url = "#{@@host}/admin/location/states"
      @states = {"states" => get_request(url)["states"]}
    end
    
    def save_data
      File.open(File.join(File.dirname(__FILE__), '../data/states.yml'), "w") { |file| 
        file.write(@states.to_yaml) 
      }
    end
end