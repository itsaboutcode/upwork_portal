module Auth
	class CallbacksController < ApplicationController
		skip_before_action :verify_authenticity_token, :authenticate_user!

		def create
			response = UpworkApis::Me.new(request.env['omniauth.auth']['credentials']['token']).call
			user = response["data"]["user"]
			OauthCredential.create_or_update_oauth_credential(
				request.env['omniauth.auth'],
				user["name"],
				user["email"],
				user["photoUrl"]
			)

			flash[:noitce] = "Account Synced!"
			redirect_to admin_oauth_credentials_path
		end

		def oauth_failure
			flash[:error] = "Account did not synced due to an error!."
    		redirect_to admin_oauth_credentials_path
		end
	end
end
