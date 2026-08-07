class AddPublishedDateTimeToProposal < ActiveRecord::Migration[7.2]
  def change
    add_column :proposals, :published_date_time, :datetime
  end
end
