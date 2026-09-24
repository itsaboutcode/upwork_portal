# Copyright (c) 2026 Fortex Solutions. All rights reserved.
require "test_helper"

## Verifies persisted hiring semantics and PostgreSQL-backed admin filter behavior.
class JobTest < ActiveSupport::TestCase
  # Keeps regression fixtures isolated from unrelated legacy job data.
  self.fixture_table_names = []

  ## Confirms callbacks persist job-specific zero despite positive client history.
  # Returns: assertion results. Errors: database and assertion failures remain visible.
  test "zero job hires override client history in stored and displayed fields" do
    job = create_hiring_job(0)
    assert_equal 516, job.total_hires
    assert_equal false, job.reload.hired
    assert_equal false, job[:hired]
    assert_equal "No", job.hiring_status
  end

  ## Confirms legacy materialized booleans cannot produce a false positive in the UI.
  # Returns: assertion results. Errors: database and assertion failures remain visible.
  test "legacy stored true remains unknown without verified job activity" do
    job = create_hiring_job(nil)
    job.update_column(:hired, true)
    assert_equal true, job.reload[:hired]
    assert_nil job.hired
    assert_nil job.hired?
    assert_equal "Unknown", job.hiring_status
    job.save!
    assert_nil job.reload[:hired]
  end

  ## Executes the real Ransack SQL against PostgreSQL for all three statuses.
  # Returns: assertion results. Errors: invalid SQL or incorrect classification fails the test.
  test "hiring filter uses verified JSON counts and ignores legacy booleans" do
    zero = create_hiring_job(0)
    positive = create_hiring_job(2)
    invalid = [nil, -1, "2", 1.5, true].map { |count| create_hiring_job(count) }
    jobs = [zero, positive] + invalid
    Job.where(id: jobs.map(&:id)).update_all(hired: true)
    relation = Job.where(id: jobs.map(&:id))
    assert_equal [zero.id], relation.ransack(job_hiring_status_eq: 0).result.pluck(:id)
    assert_equal [positive.id], relation.ransack(job_hiring_status_eq: 1).result.pluck(:id)
    assert_equal invalid.map(&:id).sort,
                 relation.ransack(job_hiring_status_eq: -1).result.pluck(:id).sort
  end

  ## Confirms detail counters retain zero and distinguish absent activity from zero.
  # Returns: assertion results. Errors: database or assertion failures remain visible.
  test "applicant and interview counts retain their independent meanings" do
    job = create_hiring_job(0)
    assert_nil job.job_interviews_count
    assert_nil job.total_applicants
    job.update!(data: job.data.merge("job_interviews_count" => 3, "totalApplicants" => 155))
    assert_equal 3, job.reload.job_interviews_count
    assert_equal 155, job.total_applicants
    assert_equal false, job.hired
    job.update!(data: job.data.merge("job_interviews_count" => 0, "totalApplicants" => 0))
    assert_equal 0, job.reload.job_interviews_count
    assert_equal 0, job.total_applicants
  end

  private

  ## Persists a job whose client history differs from its supplied job-level activity.
  # Parameters:
  # - count: Raw job hire count, including malformed values used to verify Unknown.
  # Returns:
  # - A persisted Job with normalized columns.
  # Errors:
  # - ActiveRecord persistence errors propagate to the test.
  def create_hiring_job(count)
    Job.create!(upwork_job_id: SecureRandom.uuid,
                data: {"client" => {"totalHires" => 516}, "job_hires_count" => count})
  end
end
