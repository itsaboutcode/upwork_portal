class AddCountryToJobs < ActiveRecord::Migration[7.2]
  def change
    add_column :jobs, :country, :string
  end
end
