module OmniAuth
  module Strategies
    class Upwork < OmniAuth::Strategies::OAuth2
      option :name, "upwork"

      option :client_options, {
        site: "https://www.upwork.com",
        authorize_url: "/ab/account-security/oauth2/authorize",
        token_url: "/api/v3/oauth2/token"
      }
    end
  end
end
