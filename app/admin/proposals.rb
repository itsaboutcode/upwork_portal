# NOTE: Intentionally commented out to disable proposals admin UI while keeping implementation for rollback.
=begin
ActiveAdmin.register Proposal do
  actions :all, except: [:batch_actions]

  config.batch_actions = false

  # Filters
  filter :name, as: :select, collection: -> { Proposal.pluck(:name).uniq }
  filter :status, as: :select, collection: -> { Proposal::STATUSES }
  filter :job_status, as: :select, collection: -> { Proposal.pluck(:job_status).uniq }
  filter :submitted_at, as: :date_range, label: "Proposal Submitted At"
  filter :published_date_time, as: :date_range, label: "Job Posted At"

  config.clear_action_items!

  action_item :fetch_proposals, only: :index do
    link_to 'Fetch All Proposals', fetch_proposals_admin_proposals_path, method: :get, data: { confirm: 'Are you sure you want to fetch proposals?' }
  end

  # Custom action to fetch proposals from Upwork
  collection_action :fetch_proposals, method: :get do
    if params[:access_token].present?
      proposals = UpworkApis::Proposals.new(params[:access_token]).call
    else
      Cron::SyncProposals.perform_async
    end

    redirect_to admin_proposals_path(status: status), notice: "Sidekiq Job has been enqueued to fetch proposals."
  end

  index do
  id_column

  column "Name", :name

  column "Job Title" do |proposal|
    link_to proposal.data['marketplaceJobPosting']['content']['title'], "https://www.upwork.com/jobs/~02#{proposal.data['marketplaceJobPosting']['id']}"
  end
  
  column "Job Published At", :published_date_time, sortable: :published_date_time do |proposal|
    proposal.published_date_time.blank? ? "" : proposal.published_date_time.in_time_zone.strftime("%A, %I:%M %p %d-%m-%Y")
  end

  column "Proposal Submitted At", :submitted_at, sortable: :submitted_at do |proposal|
    proposal.submitted_at.blank? ? "" : proposal.submitted_at.in_time_zone.strftime("%A, %I:%M %p %d-%m-%Y")
  end

  column "Last Client Activity At" do |proposal|
    proposal.data["marketplaceJobPosting"]["activityStat"]["jobActivity"]["lastClientActivity"].in_time_zone.strftime("%A, %I:%M %p %d-%m-%Y")
  end

  column "Proposal Status", :status, sortable: :status do |proposal|
    proposal.status
  end

  column "Job Status", :job_status, sortable: :job_status do |proposal|
    proposal.job_status
  end

  column "Total Invited To Interview" do |proposal|
    proposal.data['marketplaceJobPosting']["activityStat"]["jobActivity"]["totalInvitedToInterview"]
  end

  column "Total Hired" do |proposal|
    proposal.data['marketplaceJobPosting']["activityStat"]["jobActivity"]["totalHired"]
  end

  column "Marketplace Job Posting" do |proposal|
    proposal.data['marketplaceJobPosting']
  end

  # column :created_at
  column "Actions" do |proposal|
    link_to 'View', admin_proposal_path(proposal)  # Link to the individual proposal
  end
end
end
=end
