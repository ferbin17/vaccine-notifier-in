class CreateVaccineNotifierStates < ActiveRecord::Migration[6.1]
  def change
    create_table :vaccine_notifier_states do |t|
      t.string :name
      t.timestamps
    end
  end
end
