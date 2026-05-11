class AddThemeToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :theme, :string, default: "default", null: false
  end
end
