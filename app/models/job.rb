# Copyright (c) 2026 Fortex Solutions. All rights reserved.

## Stores marketplace jobs with hiring independent of client history.
class Job < ApplicationRecord
  has_many :job_tags
  has_many :tags, through: :job_tags

  before_save :prefill_columns

  ## Exposes searchable attributes and the verified job-hiring expression.
  # Parameters:
  # - auth_object: Optional Ransack authorization context; existing access policy is unchanged.
  # Returns:
  # - Attribute names permitted for filtering.
  # Errors:
  # - None.
  def self.ransackable_attributes(auth_object = nil)
    ["country", "job_tags_tag_id_in", "applied", "created_at", "data", "enterprise", "id", "id_value", "published_date_time", "team_name", "total_hires", "total_spent", "updated_at", "upwork_job_id", "verification_status", "job_hiring_status", "team_type"]
  end

  ## Filters verified JSON counts, ignoring legacy stored hiring booleans.
  # Returns:
  # - An Arel SQL expression yielding 1 (Yes), 0 (No), or -1 (Unknown).
  # Errors:
  # - Database errors propagate during query execution.
  # Notes:
  # - Static SQL accepts nonnegative JSON integers; -1 denotes Unknown.
  # - Numeric avoids integer overflow on oversized provider values.
  ransacker :job_hiring_status, type: :integer do
    Arel.sql(<<~SQL.squish)
      CASE WHEN json_typeof(jobs.data->'job_hires_count') = 'number'
        AND jobs.data->>'job_hires_count' ~ '^[0-9]+$'
      THEN CASE WHEN (jobs.data->>'job_hires_count')::numeric > 0 THEN 1 ELSE 0 END
      ELSE -1 END
    SQL
  end

  ## Reads a validated job count without trusting the historical hired boolean.
  # Returns:
  # - A nonnegative Integer, or nil when no verified count exists.
  # Errors:
  # - None; absent or non-object JSON is unavailable.
  def job_hires_count
    activity_count("job_hires_count")
  end

  ## Reads the count invited to interview; it does not establish interviews started.
  # Returns:
  # - A nonnegative Integer, or nil when the activity was not available.
  # Errors:
  # - None.
  def job_interviews_count
    activity_count("job_interviews_count")
  end

  ## Reads all applicants for this job from the synchronized marketplace search payload.
  # Returns:
  # - A nonnegative Integer, or nil when the applicant count is unavailable.
  # Errors:
  # - None.
  def total_applicants
    activity_count("totalApplicants")
  end

  ## Reports whether anyone was hired for this job, independent of client history.
  # Returns:
  # - true for positive counts, false for zero, nil when unavailable.
  # Errors:
  # - None.
  def hired
    count = job_hires_count
    count.nil? ? nil : count.positive?
  end

  ## Keeps boolean predicates consistent with verified activity on legacy records.
  # Returns:
  # - true, false, or nil with the same meaning as hired.
  # Errors:
  # - None.
  def hired?
    hired
  end

  ## Supplies an explicit three-state label for job lists and detail views.
  # Returns:
  # - "Unknown", "Yes", or "No" according to verified job activity.
  # Errors:
  # - None.
  def hiring_status
    return "Unknown" if hired.nil?

    hired ? "Yes" : "No"
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

  ## Shares strict count validation across independently sourced job metrics.
  # Parameters:
  # - field: Stored JSON field name for the metric being read.
  # Returns:
  # - A nonnegative Integer, or nil for absent, negative, or malformed data.
  # Errors:
  # - None; a non-object payload is treated as unavailable.
  def activity_count(field)
    count = data[field] if data.is_a?(Hash)
    count if count.is_a?(Integer) && count >= 0
  end

  ## Normalizes details and materializes the verified hiring value for mirroring.
  # Returns:
  # - The assigned country, or nil for blank data; callers ignore the result.
  # Errors:
  # - Invalid nested detail types retain the existing normalization failures.
  # Notes:
  # - Missing job activity becomes NULL, never client-derived true or fabricated false.
  def prefill_columns
    self.hired = hired
    return if data.blank?

    self.applied = data["applied"]
    self.published_date_time = data["publishedDateTime"]
    self.enterprise = data["enterprise"]
    self.total_hires = data.dig("client", "totalHires")
    self.total_spent =  data.dig("client", "totalSpent", "displayValue")
    self.verification_status = data.dig("client", "verificationStatus")
    self.team_name = data.dig("job", "ownership", "team", "name")
    self.team_type = data.dig("job", "ownership", "team", "type")
    self.country = data.dig("client", "location", "country")
  end
end
