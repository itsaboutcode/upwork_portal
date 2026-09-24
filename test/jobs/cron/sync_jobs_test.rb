# Copyright (c) 2026 Fortex Solutions. All rights reserved.
require "test_helper"
require "minitest/mock"

## Verifies that the Upwork jobs worker mirrors normalized local jobs remotely.
class CronSyncJobsTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  ## Records the worker's remote persistence lifecycle.
  class FakeRemoteJobsRepository
    ## Persisted jobs captured by the test substitute.
    attr_reader :upserts

    ## Creates an empty remote persistence recording fake.
    #
    # Returns:
    # - A fake repository ready to receive jobs.
    def initialize
      @upserts = []
      @schema_ensured = false
      @closed = false
    end

    ## Records remote schema readiness.
    #
    # Returns:
    # - true.
    def ensure_schema!
      @schema_ensured = true
    end

    ## Records a job selected for remote mirroring.
    #
    # Parameters:
    # - job: Persisted local Job containing normalized fetched data.
    #
    # Returns:
    # - The recorded Job.
    def upsert!(job)
      @upserts << job
      job
    end

    ## Records repository cleanup.
    #
    # Returns:
    # - true.
    def close
      @closed = true
    end

    ## Reports whether schema setup ran before writes.
    #
    # Returns:
    # - true when schema setup was recorded.
    def schema_ensured?
      @schema_ensured
    end

    ## Reports whether worker cleanup closed the repository.
    #
    # Returns:
    # - true after cleanup.
    def closed?
      @closed
    end
  end

  ## Verifies one fetched payload is saved locally and mirrored remotely.
  test "mirrors each normalized fetched job" do
    repository = FakeRemoteJobsRepository.new
    tag = Tag.create!(name: "Ruby", active: true)
    credential = Object.new
    credential.define_singleton_method(:fetch_or_refresh_access_token) { "test-token" }
    # Supplies independent hiring and interview activity without calling the external API.
    activity_client = Object.new
    # Parameters: job_id - requested posting. Returns: zero hires and three interview invitations. Errors: none.
    activity_client.define_singleton_method(:call) { |_job_id| {hires: 0, interviews: 3} }
    client = Object.new
    payload = fetched_job_payload
    client.define_singleton_method(:call) { |_tag_name| [{ "node" => payload }] }

    RemoteJobsRepository.stub(:from_env, repository) do
      OauthCredential.stub(:first, credential) do
        Tag.stub(:active, [tag]) do
          UpworkApis::JobActivity.stub(:new, ->(*) { activity_client }) do
            UpworkApis::MarketplaceJobs.stub(:new, ->(*) { client }) { Cron::SyncJobs.new.perform }
          end
        end
      end
    end

    assert_predicate repository, :schema_ensured?
    assert_predicate repository, :closed?
    assert_equal 1, repository.upserts.length
    assert_equal "remote-job-1", repository.upserts.first.upwork_job_id
    assert_equal "Pakistan", repository.upserts.first.country
    assert_equal 155, repository.upserts.first.total_applicants
    assert_equal 3, repository.upserts.first.job_interviews_count
    assert_equal 0, repository.upserts.first.job_hires_count
    assert_equal false, repository.upserts.first.hired
  end

  ## Verifies a remote persistence failure remains visible and still closes the repository.
  test "propagates remote write failures and closes the repository" do
    repository = FakeRemoteJobsRepository.new
    repository.define_singleton_method(:upsert!) { |_job| raise PG::ConnectionBad, "remote unavailable" }
    tag = Tag.create!(name: "Ruby", active: true)
    credential = Object.new
    credential.define_singleton_method(:fetch_or_refresh_access_token) { "test-token" }
    # Supplies independent hiring and interview activity without calling the external API.
    activity_client = Object.new
    # Parameters: job_id - requested posting. Returns: zero hires and three interview invitations. Errors: none.
    activity_client.define_singleton_method(:call) { |_job_id| {hires: 0, interviews: 3} }
    client = Object.new
    payload = fetched_job_payload
    client.define_singleton_method(:call) { |_tag_name| [{ "node" => payload }] }

    assert_raises(PG::ConnectionBad) do
      RemoteJobsRepository.stub(:from_env, repository) do
        OauthCredential.stub(:first, credential) do
          Tag.stub(:active, [tag]) do
            UpworkApis::JobActivity.stub(:new, ->(*) { activity_client }) do
              UpworkApis::MarketplaceJobs.stub(:new, ->(*) { client }) { Cron::SyncJobs.new.perform }
            end
          end
        end
      end
    end
    assert_predicate repository, :closed?
    assert Job.exists?(upwork_job_id: "remote-job-1")
  end

  private

  # Builds a complete Upwork payload accepted by Job normalization callbacks.
  #
  # Returns:
  # - A Hash representing one fetched marketplace job.
  def fetched_job_payload
    {
      "id" => "remote-job-1",
      "applied" => false,
      "totalApplicants" => 155,
      "publishedDateTime" => "2026-08-12T10:00:00Z",
      "enterprise" => false,
      "client" => {
        "totalHires" => 516,
        "totalSpent" => { "displayValue" => "100" },
        "verificationStatus" => true,
        "location" => { "country" => "Pakistan" }
      },
      "job" => { "ownership" => { "team" => { "name" => "Example", "type" => "Company" } } }
    }
  end
end
