class CreateVaccineNotifierUsers < ActiveRecord::Migration[6.1]
  def change
    create_table :vaccine_notifier_users do |t|
      t.string :full_name
      t.string :email
      t.string :phone
      t.integer :state_id
      t.integer :district_id
      t.string :pincode
      t.timestamps
    end
  end
end
