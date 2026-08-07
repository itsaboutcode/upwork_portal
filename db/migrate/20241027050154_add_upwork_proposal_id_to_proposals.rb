class AddUpworkProposalIdToProposals < ActiveRecord::Migration[7.2]
  def change
    add_column :proposals, :upwork_proposal_id, :string
  end
end
