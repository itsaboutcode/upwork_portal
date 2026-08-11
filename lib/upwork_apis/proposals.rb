module UpworkApis
  class Proposals < Base
    MAX_PAGES_PER_STATUS = Integer(ENV.fetch("UPWORK_MAX_PAGES_PER_PROPOSAL_STATUS", 3))
    MAX_PROPOSALS_PER_STATUS = Integer(ENV.fetch("UPWORK_MAX_PROPOSALS_PER_STATUS", 100))

    def call      
      all_proposals = []
      Proposal::STATUSES.each do |status|
        cursor = nil
        status_count = 0
        pages_for_status = 0
        loop do
          pages_for_status += 1
          break if status_count >= MAX_PROPOSALS_PER_STATUS

          response = UpworkApis::RateLimiter.execute do
            graphql.execute(my_proposals_query(status, cursor))
          end
          puts "========================"
          puts "Fetched #{response}"
          puts "========================"
          break if response.blank?

          status_specific_proposals = response.dig("data", "vendorProposals", "edges")
          status_specific_proposals = [] if status_specific_proposals.blank?
          all_proposals.concat(status_specific_proposals)
          status_count += status_specific_proposals.size

          page_info = response.dig("data", "vendorProposals", "pageInfo")
          total_count = response.dig("data", "vendorProposals", "totalCount")
          break if total_count.nil? || status_specific_proposals.empty?
          break unless page_info&.fetch("hasNextPage", false)

          cursor = page_info["endCursor"]

          break if status_count >= MAX_PROPOSALS_PER_STATUS
          break if pages_for_status >= MAX_PAGES_PER_STATUS
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
