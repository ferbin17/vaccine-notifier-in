class CreateVaccineNotifierVaccineAlerts < ActiveRecord::Migration[6.1]
  def change
    create_table :vaccine_notifier_vaccine_alerts do |t|
      t.integer :user_id
      t.date :date
      t.text :notified_appointment_ids
      t.timestamps
    end
  end
end
