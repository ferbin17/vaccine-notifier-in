module VaccineNotifier
  class State < ApplicationRecord
    has_many :districts
    
    def self.create_state_records
      unless self.exists?
        if File.exists?(File.join(File.dirname(__FILE__), '../../../lib/data/states.yml'))
          @states = YAML.load_file(File.join(File.dirname(__FILE__), '../../../lib/data/states.yml'))["states"]
          if @states.present?
            @states.each {|state| State.create(id: state["state_id"], name: state["state_name"]) }
          end
        else
          StateFileCreator.new.fetch_and_save_data
          create_state_records
        end
      end
    end
  end
end
