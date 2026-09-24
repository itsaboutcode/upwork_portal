# Copyright (c) 2026 Fortex Solutions. All rights reserved.

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
    # - Activity lookup failures become Unknown without interrupting detail synchronization.
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
      activity_by_job = {}
      Tag.active.each do |tag|
        puts "Syncing jobs for tag: #{tag.name}"
        access_token = oauth_credential.fetch_or_refresh_access_token
        jobs = UpworkApis::MarketplaceJobs.new(access_token).call(tag.name)
        activity_client = UpworkApis::JobActivity.new(access_token)

        jobs.each do |payload|
          begin
            job = Job.find_or_create_by(upwork_job_id: payload["node"]["id"])
            puts "Created or found job: #{job.id}" if job
          rescue ActiveRecord::RecordNotUnique
            puts "Duplicate found for upwork_job_id: #{payload['node']['id']}, fetching existing record..."
            job = Job.find_by(upwork_job_id: payload["node"]["id"])
          end

          activity_id = (payload.dig("node", "job", "id") || payload["node"]["id"]).to_s
          unless activity_by_job.include?(activity_id)
            activity_by_job[activity_id] = fetch_job_activity(activity_client, activity_id)
          end
          activity = activity_by_job[activity_id] || {}
          details = payload["node"].merge(
            "job_hires_count" => activity[:hires],
            "job_interviews_count" => activity[:interviews]
          )
          job.update!(data: details)
          job.tags << tag unless job.tags.include?(tag)
          remote_jobs.upsert!(job)
        end
      end
    ensure
      remote_jobs&.close
    end

    private

    ## Isolates optional activity failures so the remaining job details still synchronize.
    # Parameters:
    # - client: JobActivity-compatible object implementing call(job_id).
    # - job_id: Posting identifier whose verified activity is requested.
    # Returns:
    # - The client's activity Hash, or nil on a failed lookup.
    # Errors:
    # - StandardError from this optional lookup is recorded by class only and recovered.
    # Notes:
    # - Provider messages and payloads may contain secrets and must not be logged here.
    def fetch_job_activity(client, job_id)
      client.call(job_id)
    rescue StandardError => error
      Rails.logger.warn("Job hiring activity unavailable (#{error.class})")
      nil
    end
  end
end
