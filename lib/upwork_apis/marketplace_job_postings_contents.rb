module UpworkApis
  class MarketplaceJobPostingsContents < Base

    def call(ids)
      graphql.execute(params(ids))
    end

    private

    def params(ids)
      {
        'query' => "
          query marketplaceJobPostingsContents($ids: [ID!]!) {
            marketplaceJobPostingsContents(ids: $ids) {
              id
              ciphertext
              title
              description
              publishedDateTime
            }
          }
        ",
        'variables' => {
          "ids" => ids
        }
      }
    end
  end
end
