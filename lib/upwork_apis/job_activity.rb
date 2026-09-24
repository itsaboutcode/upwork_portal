# Copyright (c) 2026 Fortex Solutions. All rights reserved.

## Contains adapters for authenticated Upwork operations.
module UpworkApis
  ## Reads hiring and interview activity for one job without confusing client lifetime statistics.
  class JobActivity < Base
    ## Fetches job-specific hiring and interview invitation counts through the existing limiter.
    #
    # Parameters:
    # - job_id: Upwork marketplace posting identifier, never a client identifier.
    # Returns:
    # - A Hash with :hires and :interviews (nonnegative Integer or nil per field);
    #   nil for unavailable, denied, mismatched, or malformed responses.
    # Errors:
    # - Transport and rate-limiter errors propagate to the worker's recovery boundary.
    # Notes:
    # - Uses the caller's existing credentials; never logs tokens or provider payloads.
    def call(job_id)
      return nil if job_id.to_s.empty?

      response = RateLimiter.execute do
        graphql.execute({
          "query" => "query JobHiringActivity($id: ID!) { marketplaceJobPosting(id: $id) { id activityStat { jobActivity { totalHired totalInvitedToInterview } } } }",
          "variables" => { "id" => job_id.to_s }
        })
      end
      extract_activity(response, job_id)
    end

    private

    ## Validates the response identity and counts before allowing it into persistence.
    #
    # Parameters:
    # - response: Parsed GraphQL response, potentially containing partial data/errors.
    # - job_id: Requested posting identifier used to reject unrelated activity.
    # Returns:
    # - A Hash of independently validated counts, or nil for an unavailable response.
    # Errors:
    # - Malformed nested response types are treated as unavailable, not zero.
    def extract_activity(response, job_id)
      return nil unless response.is_a?(Hash)
      return nil if response["errors"] && response["errors"] != []

      posting = response.dig("data", "marketplaceJobPosting")
      return nil unless posting.is_a?(Hash) && posting["id"].to_s == job_id.to_s

      activity = posting.dig("activityStat", "jobActivity")
      return nil unless activity.nil? || activity.is_a?(Hash)

      {
        hires: valid_count(activity && activity["totalHired"]),
        interviews: valid_count(activity && activity["totalInvitedToInterview"])
      }
    rescue TypeError
      nil
    end

    ## Validates each independent activity field without substituting another metric.
    # Parameters:
    # - value: Raw provider count, potentially missing or malformed.
    # Returns:
    # - A nonnegative Integer, or nil when the count cannot be established.
    # Errors:
    # - None.
    def valid_count(value)
      value if value.is_a?(Integer) && value >= 0
    end
  end
end
