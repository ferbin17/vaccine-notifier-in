module VaccineNotifier
  class VaccineAlert < ApplicationRecord
    belongs_to :user
    serialize :notified_appointment_ids, Array 
  end
end
