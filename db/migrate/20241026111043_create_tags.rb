class CreateTags < ActiveRecord::Migration[7.2]
  def change
    create_table :tags do |t|
      t.string :name          # Corrected syntax for the name column
      t.boolean :active, default: false  # Corrected syntax for the active column

      t.timestamps
    end
  end
end
