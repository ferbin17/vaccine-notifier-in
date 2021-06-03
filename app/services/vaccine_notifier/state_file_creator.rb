module VaccineNotifier
  class StateFileCreator
    @@user_agent = 

    def fetch_and_save_data
      fetch_data
      save_data if @states.present?
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
      
      def fetch_data
        url = "#{VaccineNotifier::API_HOST}/admin/location/states"
        states = get_request(url)
        @states = {"states" => states["states"]} if states.present?
      end
      
      def save_data
        File.open(File.join(File.dirname(__FILE__), '../../../lib/data/states.yml'), "w+") { |file| 
          file.write(@states.to_yaml) 
        }
      end
  end
end