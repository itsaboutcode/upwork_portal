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
  after_commit :fetch_published_datatime

  def self.ransackable_attributes(auth_object = nil)
    %w[id name created_at updated_at status published_date_time submitted_at job_status]
  end

  # Include other associations if needed
  def self.ransackable_associations(auth_object = nil)
    []
  end

  def fetch_published_datatime
    oauth_credentail = OauthCredential.find_by(name: name)
    return if oauth_credentail.blank?
    return if published_date_time.present?

    response = UpworkApis::MarketplaceJobPostingsContents.new(oauth_credentail.access_token).call([data["marketplaceJobPosting"]["id"]])
    update_column(:published_date_time, response["data"]["marketplaceJobPostingsContents"][0]["publishedDateTime"].in_time_zone)
  end

  private
  def prefil_columns
    return if data.blank?

    self.submitted_at = data["auditDetails"]["createdDateTime"]["displayValue"]
    self.job_status = data['marketplaceJobPosting']["workFlowState"]["status"]
  end
end
