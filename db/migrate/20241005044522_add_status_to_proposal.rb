class AddStatusToProposal < ActiveRecord::Migration[7.2]
  def change
    add_column :proposals, :status, :string
  end
end
