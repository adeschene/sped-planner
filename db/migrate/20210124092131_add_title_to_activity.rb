class AddTitleToActivity < ActiveRecord::Migration[6.1]
  def change
    add_column :activities, :title, :string
  end
end
