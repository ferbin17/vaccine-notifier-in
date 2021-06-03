module VaccineNotifier
  class District < ApplicationRecord
    belongs_to :state
    
    def self.create_district_records
      unless self.exists?
        if File.exists?(File.join(File.dirname(__FILE__), '../../../lib/data/districts.yml'))
          @districts = YAML.load_file(File.join(File.dirname(__FILE__), '../../../lib/data/districts.yml'))["districts"]
          if @districts.present?
            @districts.each do |state_id, districts|
              state = State.find_by_id(state_id)
              if state
                p "111"
                districts.each {|district| state.districts.build(id: district["district_id"], name: district["district_name"]) }
                state.save
              end
            end
          end
        else
          DistrictFileCreator.new.fetch_and_save_data
          create_district_records
        end
      end
    end
  end
end
