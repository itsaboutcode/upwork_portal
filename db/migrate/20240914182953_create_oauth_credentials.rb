class CreateOauthCredentials < ActiveRecord::Migration[7.2]
  def change
    create_table :oauth_credentials do |t|
      t.references :user, null: false, foreign_key: true
      t.string :provider
      t.string :uid
      t.string :access_token
      t.string :refresh_token
      t.datetime :expires_at

      t.timestamps
    end
  end
end
