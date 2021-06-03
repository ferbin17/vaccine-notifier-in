class AddAgeAndFeeTypeToUser < ActiveRecord::Migration[6.1]
  def change
    add_column :vaccine_notifier_users, :age, :integer
    add_column :vaccine_notifier_users, :fee_type, :string 
  end
end
