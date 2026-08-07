class AddEmailToOauthCredentials < ActiveRecord::Migration[7.2]
  def change
    remove_column :oauth_credentials, :user_id
    add_column :oauth_credentials, :email, :string
    add_column :oauth_credentials, :name, :string
    add_column :oauth_credentials, :photo_url, :string
  end
end
