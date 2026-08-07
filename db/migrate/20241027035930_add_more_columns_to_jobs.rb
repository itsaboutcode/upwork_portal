class AddMoreColumnsToJobs < ActiveRecord::Migration[7.2]
  def change
    add_column :jobs, :applied, :boolean, default: false
    add_column :jobs, :published_date_time, :datetime
    add_column :jobs, :enterprise, :boolean
    add_column :jobs, :total_hires, :integer
    add_column :jobs, :total_spent, :decimal
    add_column :jobs, :verification_status, :boolean, default: false
    add_column :jobs, :hired, :boolean, default: false
    add_column :jobs, :team_name, :string
    add_column :jobs, :team_type, :string
    add_reference :jobs, :tag, foreign_key: true
  end
end
