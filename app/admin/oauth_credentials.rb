ActiveAdmin.register OauthCredential do
  config.batch_actions = false
  config.filters = false
  actions :index

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
        link_to("Re-Sync Account", "/auth/upwork", method: :get, data: { confirm: "Are you sure?" }),
        link_to("Fetch Proposals", fetch_proposals_admin_proposals_path(access_token: o.access_token), method: :get, data: { confirm: "Are you sure?" }),
      ], " | ")
    end

  end
end
