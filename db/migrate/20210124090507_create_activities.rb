class CreateActivities < ActiveRecord::Migration[6.1]
  def change
    create_table :activities do |t|
      t.date :date
      t.integer :block

      t.timestamps
    end
  end
end
