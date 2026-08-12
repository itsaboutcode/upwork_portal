require "sidekiq-scheduler"

## Scheduled background operations.
module Cron
  ## Fetches Upwork marketplace jobs and persists them locally and to the remote jobs mirror.
  class SyncJobs
    include Sidekiq::Job

    sidekiq_options retry: false, queue: "jobs", unique: :until_executed

    ## Synchronizes every active tag and mirrors each completed local job remotely.
    #
    # Returns:
    # - The active tag collection after iteration completes.
    #
    # Errors:
    # - RemoteJobsRepository errors when configuration, schema validation, or mirroring fails.
    # - Upwork API and ActiveRecord errors when fetching or local persistence fails.
    #
    # Notes:
    # - Local job data and tag relationships are committed before each remote upsert.
    # - Repository cleanup runs for successful and failed synchronization attempts.
    def perform
      puts "Starting job synchronization..."
      remote_jobs = RemoteJobsRepository.from_env
      remote_jobs.ensure_schema!
      oauth_credential = OauthCredential.first
      Tag.active.each do |tag|
        puts "Syncing jobs for tag: #{tag.name}"
        jobs = UpworkApis::MarketplaceJobs.new(oauth_credential.fetch_or_refresh_access_token).call(tag.name)

        jobs.each do |payload|
          begin
            job = Job.find_or_create_by(upwork_job_id: payload["node"]["id"])
            puts "Created or found job: #{job.id}" if job
          rescue ActiveRecord::RecordNotUnique
            puts "Duplicate found for upwork_job_id: #{payload['node']['id']}, fetching existing record..."
            job = Job.find_by(upwork_job_id: payload["node"]["id"])
          end

          job.update!(data: payload["node"])
          job.tags << tag unless job.tags.include?(tag)
          remote_jobs.upsert!(job)
        end
      end
    ensure
      remote_jobs&.close
    end
  end
end
