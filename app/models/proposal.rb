class Proposal < ApplicationRecord
  STATUSES = [
    'Accepted',
    'Declined', # Client has declined proposal
    'Withdrawn',
    'Offered',
    'Activated', # Client has sent an message - Interview Invitation
    'Archived',
    'Hired', # Client has hired me
    'Pending',
  ]

  before_save :prefil_columns
  after_commit :enqueue_published_date_time_fetch

  def self.ransackable_attributes(auth_object = nil)
    %w[id name created_at updated_at status published_date_time submitted_at job_status]
  end

  # Include other associations if needed
  def self.ransackable_associations(auth_object = nil)
    []
  end

  def enqueue_published_date_time_fetch
    return if OauthCredential.find_by(name: name).blank?
    return if published_date_time.present?
    return if data.blank?

    FetchProposalPublishedDateTimeJob.perform_async(id)
  end

  private
  def prefil_columns
    return if data.blank?

    self.submitted_at = data["auditDetails"]["createdDateTime"]["displayValue"]
    self.job_status = data['marketplaceJobPosting']["workFlowState"]["status"]
  end
end
