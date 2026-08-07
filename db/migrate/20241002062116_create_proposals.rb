class CreateProposals < ActiveRecord::Migration[7.2]
  def change
    create_table :proposals do |t|
      t.json :data

      t.timestamps
    end
  end
end
