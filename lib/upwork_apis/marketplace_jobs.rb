module UpworkApis
  class MarketplaceJobs < Base

    def call(tags)
      all_jobs = []
      cursor = nil
      loop do
        response = graphql.execute(params(tags, cursor))
        puts "========================"
        puts "Fetched #{response}"
        puts "========================"
        jobs = response.dig("data", "marketplaceJobPostingsSearch", "edges")
        all_jobs.concat(jobs)

        page_info = response.dig("data", "marketplaceJobPostingsSearch", "pageInfo")
        break unless page_info["hasNextPage"]

        cursor = page_info["endCursor"]

        break if all_jobs.size > 50
      end
      all_jobs
    end

    private

    def params(tag, cursor)
      marketPlaceJobFilter = {
        searchExpression_eq: tag,
        verifiedPaymentOnly_eq: true,
      }

      {
        'query' => "
          query marketplaceJobPostingsSearch($marketPlaceJobFilter: MarketplaceJobPostingsSearchFilter, $searchType: MarketplaceJobPostingSearchType, $sortAttributes: [MarketplaceJobPostingSearchSortAttribute]) {
            marketplaceJobPostingsSearch(marketPlaceJobFilter: $marketPlaceJobFilter, searchType: $searchType, sortAttributes: $sortAttributes) {
              totalCount
              edges {
                cursor
                node {
                  id
                  job {
                    id
                    # title
                    ownership {
                      company {
                        id
                        name
                        type
                        active
                        # company {
                        #   id
                        #   name
                        #   logoURL
                        #   displayName
                        #   companyName
                        #   # country
                        #   # agencyDetails
                        #   # jobPosts
                        # }
                        photoUrl
                      }
                      team {
                        id
                        name
                        type
                        active
                        company {
                          id
                          name
                          logoURL
                          displayName
                          companyName
                          # country
                          # agencyDetails
                          # jobPosts
                        }
                        photoUrl
                      }
                    }
                  }
                  title
                  description
                  ciphertext
                  duration
                  durationLabel
                  engagement
                  amount {
                    rawValue
                    currency
                    displayValue
                  }
                  category
                  subcategory
                  freelancersToHire
                  enterprise
                  totalApplicants
                  premium
                  applied
                  createdDateTime
                  publishedDateTime
                  client {
                    memberSinceDateTime
                    totalHires
                    totalPostedJobs
                    totalSpent {
                      rawValue
                      currency
                      displayValue
                    }
                    verificationStatus
                    location {
                      city
                      state
                      country
                      timezone
                    }
                    totalReviews
                    totalFeedback
                    companyRid
                    companyName
                    memberSinceDateTime
                  }
                  skills {
                    name
                    prettyName
                    highlighted
                  }
                  hourlyBudgetType
                  hourlyBudgetMin {
                    rawValue
                    currency
                    displayValue
                  }
                  hourlyBudgetMax {
                    rawValue
                    currency
                    displayValue
                  }
                }
              }
              pageInfo {
                hasNextPage
                endCursor
              }
            }
          }
        ",
        'variables' => {
          "marketPlaceJobFilter" => marketPlaceJobFilter,
          "searchType" => "USER_JOBS_SEARCH",  # Define searchType correctly
          "sortAttributes" => { "field" => "RECENCY" },
        }
      }
    end
  end
end
