## Email address allowed to view and synchronize OAuth credentials.
ALLOWED_OAUTH_CREDENTIAL_EMAIL = "admin@example.com".freeze

ActiveAdmin.register OauthCredential do
  config.batch_actions = false
  config.filters = false
  actions :index

  menu if: proc { current_user&.email == ALLOWED_OAUTH_CREDENTIAL_EMAIL }

  controller do
    before_action :authorize_oauth_credential_access!

    private

    # Restricts OAuth credential access to the designated administrative account.
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
    # - This is a security boundary for stored third-party OAuth metadata.
    def authorize_oauth_credential_access!
      authenticated_user = request.env["warden"]&.user(scope: :user)
      return if authenticated_user&.email == ALLOWED_OAUTH_CREDENTIAL_EMAIL

      redirect_to admin_root_path, alert: "You are not authorized to view OAuth credentials."
    end
  end

  action_item :sync_account, only: :index do
    link_to "Sync New Upwork Account", "/auth/upwork", class: "button", method: :get
  end

  index do
    selectable_column
    id_column
    column :name
    column :email
    column :photo_url do |record|
      image_tag record.photo_url if record.photo_url.present?
    end
    column :provider
    # column :access_token
    # column :refresh_token
    column :created_at
    column :updated_at
    column :expires_at
    column "Actions" do |o|
      safe_join([
        link_to("Re-Sync Account", "/auth/upwork", method: :get, data: { confirm: "Are you sure?" })
        # link_to("Fetch Proposals", fetch_proposals_admin_proposals_path(access_token: o.access_token), method: :get, data: { confirm: "Are you sure?" }),
      ], " | ")
    end
  end
end
