class CreateJobs < ActiveRecord::Migration[7.2]
  def change
    create_table :jobs do |t|
      t.json :data

      t.timestamps
    end
  end
end
