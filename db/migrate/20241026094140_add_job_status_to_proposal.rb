class AddJobStatusToProposal < ActiveRecord::Migration[7.2]
  def change
    add_column :proposals, :job_status, :string
  end
end
