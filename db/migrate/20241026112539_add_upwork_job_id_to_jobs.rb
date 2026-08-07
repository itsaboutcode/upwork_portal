class AddUpworkJobIdToJobs < ActiveRecord::Migration[7.2]
  def change
    add_column :jobs, :upwork_job_id, :string
  end
end
