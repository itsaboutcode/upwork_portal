ActiveAdmin.register Proposal do
  config.batch_actions = false

  menu priority: 4, if: proc { current_user&.admin? }

  controller do
    before_action :authorize_proposal_access!

    private

    # Restricts proposal data and synchronization actions to application administrators.
    #
    # Parameters:
    # - None.
    #
    # Returns:
    # - nil when access is allowed; otherwise the result of redirecting to the admin root.
    #
    # Errors:
    # - No expected errors; unauthorized access is handled with a redirect and alert.
    #
    # Notes:
    # - This server-side guard protects direct requests in addition to hiding navigation.
    def authorize_proposal_access!
      authenticated_user = request.env["warden"]&.user(scope: :user)
      return if authenticated_user&.admin?

      redirect_to admin_root_path, alert: "You are not authorized to view proposals."
    end
  end

  filter :name, as: :select, collection: -> { Proposal.distinct.pluck(:name) }
  filter :status, as: :select, collection: -> { Proposal::STATUSES }
  filter :job_status, as: :select, collection: -> { Proposal.distinct.pluck(:job_status) }
  filter :submitted_at, as: :date_range, label: "Proposal Submitted At"
  filter :published_date_time, as: :date_range, label: "Job Posted At"

  config.clear_action_items!

  action_item :fetch_proposals, only: :index do
    link_to "Fetch All Proposals", fetch_proposals_admin_proposals_path,
            method: :get, data: { confirm: "Are you sure you want to fetch proposals?" }
  end

  collection_action :fetch_proposals, method: :get do
    if params[:access_token].present?
      UpworkApis::Proposals.new(params[:access_token]).call
    else
      Cron::SyncProposals.perform_async
    end

    redirect_to admin_proposals_path, notice: "Sidekiq job has been enqueued to fetch proposals."
  end

  index do
    id_column
    column :name
    column "Job Title" do |proposal|
      posting = proposal.data["marketplaceJobPosting"]
      link_to posting.dig("content", "title"), "https://www.upwork.com/jobs/~02#{posting["id"]}"
    end
    column "Job Published At", :published_date_time, sortable: :published_date_time do |proposal|
      proposal.published_date_time&.in_time_zone&.strftime("%A, %I:%M %p %d-%m-%Y") || ""
    end
    column "Proposal Submitted At", :submitted_at, sortable: :submitted_at do |proposal|
      proposal.submitted_at&.in_time_zone&.strftime("%A, %I:%M %p %d-%m-%Y") || ""
    end
    column "Last Client Activity At" do |proposal|
      activity_at = proposal.data.dig(
        "marketplaceJobPosting", "activityStat", "jobActivity", "lastClientActivity"
      )
      activity_at.present? ? activity_at.in_time_zone.strftime("%A, %I:%M %p %d-%m-%Y") : ""
    end
    column "Proposal Status", :status
    column "Job Status", :job_status
    column "Total Invited To Interview" do |proposal|
      proposal.data.dig("marketplaceJobPosting", "activityStat", "jobActivity", "totalInvitedToInterview")
    end
    column "Total Hired" do |proposal|
      proposal.data.dig("marketplaceJobPosting", "activityStat", "jobActivity", "totalHired")
    end
    column "Marketplace Job Posting" do |proposal|
      proposal.data["marketplaceJobPosting"]
    end
    column "Actions" do |proposal|
      link_to "View", admin_proposal_path(proposal)
    end
  end
end
