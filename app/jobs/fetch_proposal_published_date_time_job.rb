class FetchProposalPublishedDateTimeJob
  include Sidekiq::Job

  sidekiq_options queue: "proposals", retry: 3, unique: :until_executed

  def perform(proposal_id)
    proposal = Proposal.find_by(id: proposal_id)
    return if proposal.blank?
    return if proposal.published_date_time.present?
    return if proposal.data.blank?

    oauth_credential = OauthCredential.find_by(name: proposal.name)
    return if oauth_credential.blank?

    response = UpworkApis::MarketplaceJobPostingsContents.new(oauth_credential.access_token).call(
      [proposal.data["marketplaceJobPosting"]["id"]]
    )
    published_at = response.dig("data", "marketplaceJobPostingsContents", 0, "publishedDateTime")
    return if published_at.blank?

    proposal.update_column(:published_date_time, published_at.in_time_zone)
  end
end
