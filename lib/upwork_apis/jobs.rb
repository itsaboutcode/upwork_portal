module UpworkApis
  class Jobs < Base
    def call
      debugger
      # begin
      #   data = graphql.execute(introspection_params)
      #   if data['errors']
      #     puts "Errors: #{data['errors']}"
      #   end
      #   data
      # rescue StandardError => e
      #   puts "An error occurred: #{e.message}"
      # end
    end




    private

    def params
      {
        'query' => "
          query {
            vendorProposals {
              edges {
                node {
                  id
                  status {
                    id
                    name
                  }
                  jobPosting {
                    id
                    title
                    client {
                      id
                      name
                    }
                  }
                  createdAt
                  updatedAt
                }
              }
            }
          }
        "
      }
    end
  end
end
