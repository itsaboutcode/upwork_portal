class Job < ApplicationRecord
  has_many :job_tags
  has_many :tags, through: :job_tags

  before_save :prefill_columns

  def self.ransackable_attributes(auth_object = nil)
    ["country", "job_tags_tag_id_in", "applied", "created_at", "data", "enterprise", "id", "id_value", "published_date_time", "team_name", "total_hires", "total_spent", "updated_at", "upwork_job_id", "verification_status", "hired", "team_type"]
  end

  # Allow 'tags' association for ransack
  def self.ransackable_associations(auth_object = nil)
    super + ['tags']
  end

  def budget
    amount = data.dig("amount", "displayValue")
    return "$#{amount}" if amount.present?

    ""
  end

  def hourly_budget
    min = data.dig("hourlyBudgetMin", "displayValue")
    max = data.dig("hourlyBudgetMax", "displayValue")
    return "$#{min} - $#{max}" if min.present? || max.present?

    ""
  end

  private

  def prefill_columns
    return if data.blank?

    self.applied = data["applied"]
    self.published_date_time = data["publishedDateTime"]
    self.enterprise = data["enterprise"]
    self.total_hires = data.dig("client", "totalHires")
    self.hired = data.dig("client", "totalHires").zero? ? false : true
    self.total_spent =  data.dig("client", "totalSpent", "displayValue")
    self.verification_status = data.dig("client", "verificationStatus")
    self.team_name = data.dig("job", "ownership", "team", "name")
    self.team_type = data.dig("job", "ownership", "team", "type")
    self.country = data.dig("client", "location", "country")
  end
end
