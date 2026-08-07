class Tag < ApplicationRecord
  has_many :job_tags
  has_many :jobs, through: :job_tags

  scope :active, -> { where(active: true) }

	def self.ransackable_attributes(auth_object = nil)
    ["active", "created_at", "id", "name", "updated_at"]
  end
end
