class OauthCredential < ApplicationRecord

  scope :upwork, ->{ where(provider: 'upwork') } 

  def self.ransackable_attributes(auth_object = nil)
    ["access_token", "created_at", "expires_at", "id", "provider", "refresh_token", "uid", "updated_at", "user_id"]
  end
  def self.ransackable_associations(auth_object = nil)
    ["user"]
  end

  def self.create_or_update_oauth_credential(auth_hash, name, email, photo_url)
    credential = OauthCredential.find_or_initialize_by(email: email)
    credential.provider = auth_hash.provider
    credential.name = name
    credential.photo_url = photo_url
    credential.uid = auth_hash.uid
    credential.access_token = auth_hash.credentials.token
    credential.refresh_token = auth_hash.credentials.refresh_token
    credential.expires_at = Time.at(auth_hash.credentials.expires_at).to_datetime
    credential.save! # Save the credential
  end

  def fetch_or_refresh_access_token
    return access_token if expires_at > Time.zone.now

    force_refresh
  end

  def force_refresh
    response = HTTParty.post('https://www.upwork.com/api/v3/oauth2/token', {
      body: {
        grant_type: 'refresh_token',
        refresh_token: refresh_token,
        client_id: ENV.fetch('UPWORK_CLIENT_ID'),
        client_secret: ENV.fetch('UPWORK_CLIENT_SECRET'),
      },
      headers: { 'Content-Type' => 'application/x-www-form-urlencoded' }
    })

    if response.success?
      new_access_token = response.parsed_response['access_token']
      new_refresh_token = response.parsed_response['refresh_token']
      new_expiration_time = (Time.current + response.parsed_response['expires_in'].to_i).to_datetime

      update(access_token: new_access_token, refresh_token: new_refresh_token, expires_at: new_expiration_time)
      access_token
    else
      response.message
    end
  end
end
