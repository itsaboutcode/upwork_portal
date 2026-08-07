class AddSubmittedAtToProposal < ActiveRecord::Migration[7.2]
  def change
    add_column :proposals, :submitted_at, :datetime
  end
end
