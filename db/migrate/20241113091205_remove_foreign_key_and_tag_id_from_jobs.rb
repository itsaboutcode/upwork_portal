class RemoveForeignKeyAndTagIdFromJobs < ActiveRecord::Migration[7.2]
  def change
    # Remove the foreign key constraint (if it exists)
    if foreign_key_exists?(:jobs, :tags)
      remove_foreign_key :jobs, :tags
    end

    # Remove the index on tag_id (if it exists)
    if index_exists?(:jobs, :tag_id)
      remove_index :jobs, :tag_id
    end

    # Remove the tag_id column from the jobs table
    remove_column :jobs, :tag_id, :integer
  end
end
