ActiveAdmin.register Job do
  actions :all, except: [:batch_actions]

  config.batch_actions = false

  filter :team_name, as: :select, collection: -> { Job.pluck(:team_name).uniq }
  filter :applied
  filter :enterprise
  filter :verification_status
  filter :hired
  filter :team_type, as: :select, collection: -> { Job.pluck(:team_type).uniq }
  filter :tags, as: :select, 
                collection: -> { Tag.all.collect { |t| [t.name, t.id] } },
                input_html: { multiple: true, class: "chosen-select" }, 
                label: "Select Tags"
  filter :country, as: :select, 
                collection: -> { Job.pluck(:country).uniq },
                input_html: { multiple: true, class: "chosen-select" }, 
                label: "Select Country"

  filter :published_date_time, as: :date_range, label: "Job Posted At"
  
  config.clear_action_items!

  action_item :fetch_jobs, only: :index do
    link_to 'Fetch All Jobs', fetch_jobs_admin_jobs_path, method: :get, data: { confirm: 'Are you sure you want to fetch jobs?' }
  end

  collection_action :fetch_jobs, method: :get do
    Cron::SyncJobs.perform_async

    redirect_to admin_jobs_path(status: status), notice: "Sidekiq Job has been enqueued to fetch jobs."
  end

  index do
    selectable_column
    id_column
    column "Title" do |job|
      link_to job.data["title"], "https://www.upwork.com/jobs/~02#{job.data['id']}"
    end

    column :team_name
    column "Team Type" do |job|
      job.data.dig("job", "ownership", "team", "type")
    end
    column :country
    column :applied
    column :enterprise
    column :total_hires
    column :total_spent do |job|
      "$#{job.total_spent.to_f}"
    end
    column "Engagement" do |job|
      job.data["engagement"]
    end
    column "Duration" do |job|
      job.data["duration"]
    end
    column "Duration Label" do |job|
      job.data["durationLabel"]
    end
    column "Budget" do |job|
      job.budget
    end
    column "Hourly Budget" do |job|
      job.hourly_budget
    end
    column :total_applicants do |job|
      job.data.dig("totalApplicants")
    end
    column :total_posted_jobs do |job|
      job.data.dig("client", "totalPostedJobs")
    end
    column :verification_status
    column :published_date_time do |job|
      job.published_date_time&.in_time_zone&.strftime("%A, %I:%M %p %d-%m-%Y")
    end
    column "Tags" do |job|
      job.tags.pluck(:name).join(', ') # Show associated tag names
    end
    column :photo_url do |job|
      url = job.data.dig("job", "ownership", "team", "photoUrl")
      image_tag url, width: "50px" if url.present?
    end
    column "Actions" do |job|
      link_to 'View', admin_job_path(job)
    end
  end

  form do |f|
    f.inputs do
      f.input :data, as: :jsonb # Use as text if you prefer a textarea
    end
    f.actions
  end
end
