class CreateTimeslots < ActiveRecord::Migration[6.1]
  def change
    create_table :timeslots do |t|
      t.string  :label,    null: false
      t.integer :position, null: false

      t.timestamps
    end

    add_index :timeslots, :position, unique: true
  end
end
