module UpworkApis
  class Proposals < Base
    def call      
      all_proposals = []
      Proposal::STATUSES.each do |status|
        cursor = nil
        status_specific_proposals = []
        loop do
          response = graphql.execute(my_proposals_query(status, cursor))
          puts "========================"
          puts "Fetched #{response}"
          puts "========================"

          status_specific_proposals = response.dig("data", "vendorProposals", "edges")
          all_proposals.concat(status_specific_proposals)

          page_info = response.dig("data", "vendorProposals", "pageInfo")
          break if response["data"]["vendorProposals"]["totalCount"].nil?
          break unless page_info["hasNextPage"]

          cursor = page_info["endCursor"]

          break if all_proposals.size >= 100 
        end
      end

      all_proposals
    end

    private

    def my_proposals_query(status, cursor)
      {
        'query' => "
          query vendorProposals(
            $filter: VendorProposalFilter!,
            $sortAttribute: VendorProposalSortAttribute!,
            $pagination: Pagination!
          ) {
            vendorProposals(
              filter: $filter,
              sortAttribute: $sortAttribute,
              pagination: $pagination
            ) {
              totalCount
              edges {
                node {
                  id
                  user {
                    id
                    name
                  }
                  marketplaceJobPosting {
                    id
                    activityStat {
                      jobActivity {
                        lastClientActivity
                        invitesSent
                        totalInvitedToInterview
                        totalHired
                        totalUnansweredInvites
                        totalOffered
                        totalRecommended
                      }
                    }
                    workFlowState {
                      status
                    }
                    content {
                      title
                      description
                    }
                    clientCompanyPublic {
                      id
                      city
                      state
                      country {
                        name
                        active
                      }
                      timezone
                      # Don't have permissioin to payment info. Need to request to upwork support for getting an access
                      # paymentVerification {
                      #   # status
                      #   paymentVerified
                      # }
                      agencyDetails {
                        vetted
                        topRatedStatus
                        topRatedPlusStatus
                      }
                    }
                    # clientProposals {
                    #   totalCount
                    # }
                  }
                  terms {
                    chargeRate {
                      rawValue
                      currency
                      displayValue
                    }
                  }
                  coverLetter
                  auditDetails {
                    createdDateTime {
                      displayValue
                    }
                  }
                  status {
                    status
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
          'filter' => {
            "status_eq": status,
          },
          'sortAttribute' => { "field": "CREATEDDATETIME", "sortOrder": "DESC" },
          'pagination' => {
            'first' => 40,
            'after' => cursor  # Use the cursor for pagination
          }
        }
      }
    end
  end
end
