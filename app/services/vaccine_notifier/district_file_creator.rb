module VaccineNotifier
  class DistrictFileCreator

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
      
      def fetch_states
        if File.exists?(File.join(File.dirname(__FILE__), '../../../lib/data/states.yml'))
          @states = YAML.load_file(File.join(File.dirname(__FILE__), '../../../lib/data/states.yml'))["states"]
        else
          StateFileCreator.new.fetch_and_save_data
          State.create_state_records
          fetch_states
        end
      end
      
      def fetch_data(state_id)
        url = "#{VaccineNotifier::API_HOST}/admin/location/districts/#{state_id}"
        districts = get_request(url)["districts"]
        districts
      end
      
      def save_data
        File.open(File.join(File.dirname(__FILE__), '../../../lib/data/districts.yml'), "w+") { |file| 
          file.write(@districts.to_yaml) 
        }
      end
  end
end