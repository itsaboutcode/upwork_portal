require 'sidekiq-scheduler'

module Cron
	class SyncProposals
		include Sidekiq::Job

		sidekiq_options retry: false, queue: "proposals", unique: :until_executed

	  def perform
	    OauthCredential.all.each do |o|
	      proposals = UpworkApis::Proposals.new(o.access_token).call

	      proposals.each_with_index do |p, index|
			begin
				proposal = Proposal.find_or_create_by(upwork_proposal_id: p["node"]["id"])
			rescue ActiveRecord::RecordNotUnique
				proposal = Proposal.find_by(upwork_proposal_id: p["node"]["id"])
			end
			
			proposal&.update(
				data: p["node"],
				status: p["node"].dig('status', 'status'),
				name: p["node"]["user"]["name"]
			)
			puts "#{index}- Updated Proposal ID: #{proposal.id}"
	      end
	    end
	  end
	end
end
