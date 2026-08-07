class AddNameToProposal < ActiveRecord::Migration[7.2]
  def change
     add_column :proposals, :name, :string
  end
end
