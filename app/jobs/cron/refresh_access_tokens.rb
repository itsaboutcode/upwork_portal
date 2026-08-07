require 'sidekiq-scheduler'

module Cron
	class RefreshAccessTokens
		include Sidekiq::Job

    sidekiq_options retry: false, unique: :until_executed

    def perform
      OauthCredential.all.each do |o|
        o.force_refresh
      end
    end
  end
end
