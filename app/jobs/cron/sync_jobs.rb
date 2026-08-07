require 'sidekiq-scheduler'

module Cron
  class SyncJobs
    include Sidekiq::Job

    sidekiq_options retry: false, queue: "jobs", unique: :until_executed

    def perform
      puts "Starting job synchronization..."
      o = OauthCredential.first
      Tag.active.each do |tag|
        puts "Syncing jobs for tag: #{tag.name}"
        jobs = UpworkApis::MarketplaceJobs.new(o.fetch_or_refresh_access_token).call(tag.name)

        jobs.each do |j|
          begin
            job = Job.find_or_create_by(upwork_job_id: j["node"]["id"])
            puts "Created or found job: #{job.id}" if job
          rescue ActiveRecord::RecordNotUnique
            puts "Duplicate found for upwork_job_id: #{j['node']['id']}, fetching existing record..."
            job = Job.find_by(upwork_job_id: j["node"]["id"])
          end

          job&.update(data: j["node"])
          job&.tags << tag unless job&.tags&.include?(tag)
        end
      end
    end
  end
end
