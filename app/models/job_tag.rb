class JobTag < ApplicationRecord
  belongs_to :job
  belongs_to :tag

  def self.ransackable_attributes(auth_object = nil)
    ["created_at", "id", "job_id", "tag_id", "updated_at"]
  end
end
