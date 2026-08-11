require 'upwork/api'
require 'upwork/api/routers/graphql'
require 'upwork/api/routers/auth'
require 'upwork/api/routers/messages'
require 'upwork/api/routers/reports/time'
require 'upwork/api/routers/freelancers/search'

module UpworkApis
  class Base
    attr_accessor :graphql

    def initialize(access_token = OauthCredential.upwork.first.access_token)
      config = Upwork::Api::Config.new({
        'client_id'     => ENV.fetch('UPWORK_CLIENT_ID'),
        'client_secret' => ENV.fetch('UPWORK_CLIENT_SECRET'),
        'redirect_uri'  => "#{ENV.fetch('BASE_URL')}/auth/upwork/callback",
        "access_token"  => access_token
      })
      client = Upwork::Api::Client.new(config)
      @graphql = Upwork::Api::Routers::Graphql.new(client)
    end

    def params
      yield
    end

    def call
      UpworkApis::RateLimiter.execute do
        graphql.execute(params)
      end
    end

    # Get available fields for a specific type
    def find_available_fields(type_name)
      {
        'query' => "
          {
            __type(name: \"#{type_name}\") {
              fields {
                name
                type {
                  name
                  kind
                  ofType {
                    name
                    kind
                  }
                }
              }
            }
          }
        "
      }
    end

    # Execute the introspection query to get fields
    def introspection_query
      UpworkApis::RateLimiter.execute do
        graphql.execute(introspection_params)
      end
    end

    private

    def introspection_params
      {
        'query' => "
          {
            __schema {
              queryType {
                fields {
                  name
                }
              }
            }
          }
        "
      }
    end
  end
end
