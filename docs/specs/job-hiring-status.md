<!-- Copyright (c) 2026 Fortex Solutions. All rights reserved. -->

# Job hiring status

## Contract

Client lifetime hires (`client.totalHires`, persisted as `total_hires`) are independent
of hires on a particular job. Job activity is fetched using the existing authenticated
Upwork GraphQL client and rate limiter. `UpworkApis::JobActivity#call(job_id)` returns
a Hash with independently validated `hires` and `interviews` counts (integer or nil),
or nil for an inaccessible/missing/invalid response; transport failures propagate to the synchronization boundary. Job IDs must match the response.
API errors and credentials must never be included in the new diagnostic log.

Persist the count under `data.job_hires_count`; derive `hired` as true for a positive
integer, false for zero, and nil otherwise. Missing information is Unknown, not No.
Legacy stored booleans are not evidence and must not affect display or filtering.
The JSON count is the authoritative source; the nullable boolean remains a materialized
value for compatibility with the remote jobs mirror. A failed fresh lookup replaces
the count with nil so an old value is not presented as newly confirmed.

## Acceptance scenarios

- Given a client with 516 lifetime hires and zero hires on this job, when saved and
  displayed, then client hires remain 516, job hires are 0, and Hired is No.
- Given two hires on this job, then job hires are 2 and Hired is Yes.
- Given missing, negative, string, fractional, denied, or malformed activity, then
  job hires and Hired are Unknown; a client hire count must never fill the gap.
- Given a legacy stored hired=true with no verified count, then the detail view,
  index, predicate, and filter treat the job as Unknown before any backfill.
- Given the same job in multiple tag results, then fetch its activity once per run.
- Given a failed activity request, then continue syncing job details and mirror an
  unknown count without logging credentials or provider response payloads.
- Given a remote persistence failure, then preserve the existing failure and cleanup
  behavior; no silent success is reported.

## Design and validation

Reuse Base/RateLimiter and the existing worker/model/repository boundaries. The API
client is substituted in worker tests; the GraphQL transport is substituted in API
contract tests. No new interface hierarchy, dependency, or database column is needed.
Model and API tests must fail before the implementation and pass afterward. Require
at least 90% line coverage for changed production code. Isolated coverage is not proof
of Rails callback, SQL filter, ActiveAdmin, or database integration behavior.

## Rollout and rollback

Deploy app and worker together after validation. Existing local rows immediately
show Unknown unless they contain a valid count. Normal synchronization refreshes only
jobs returned by searches; historical jobs are not automatically refetched.

Before correcting production rows or the remote mirror, back up both databases and
verify remote `hired` accepts NULL. Inventory rows missing `job_hires_count` and old
boolean values without modifying them. Recalculate local booleans in batches and
mirror through `RemoteJobsRepository`, checking affected counts and sampling job IDs.
Obtain separate authorization for these production data writes. Do not reset databases.
For historical actual counts, an explicitly scoped, rate-limited refresh is required.

Rollback requires restoring the matching application version and saved affected data;
the old code will otherwise recreate the incorrect client-based flags. No schema or
lockfile changes are required. Upwork account access must be verified in the target
environment; unavailable access yields Unknown, never fabricated zero.

### Operator verification (read-only)

After deploying the matching app and worker image, compare a known job in the portal
with fresh Upwork activity. The UI and JSON-derived filter do not require a backfill.
This inventory counts legacy/unknown rows still carrying an old stored boolean:

```bash
docker compose exec -T app bin/rails runner 'puts Job.ransack(job_hiring_status_eq: -1).result.where.not(hired: nil).count'
```

Do not treat a nonzero result as a successful repair. The raw local boolean and any
previously mirrored rows remain stale until corrected or synchronized. A production
repair should record job IDs and old values, process bounded batches, normalize and
save each local record, mirror through the existing repository, and record failures
for retry. A live repair script is deliberately not provided before checking actual
remote schema/permissions and obtaining production-write authorization.

The old `hired` filter parameter is no longer allowlisted because it targets stale
booleans. Use the dashboard's new `job_hiring_status` filter; bookmarked old filters
must be reselected. Keep client lifetime `total_hires` unchanged.

## Verification evidence

Run `bin/check-job-hiring` for isolated contracts and an enforced 90% line-coverage
threshold: changed model hiring declarations plus the complete JobActivity and
SyncJobs files. It uses Ruby's Coverage/Minitest and controlled external boundaries;
it does not load ActiveAdmin or execute SQL. The full model's unrelated budget and
association methods are outside this change's coverage scope.

The initial regression failed with `Expected false, Actual true` for client 516/job 0.
The completed isolated suite passed 10 tests and 138 assertions. Coverage: model hiring
declarations 96.3%, JobActivity 100%, SyncJobs 94.12%. Ruby syntax and diff whitespace
checks passed. Every changed production method was reviewed for source documentation.

Rails validation command:

```bash
bin/rails test test/models/job_test.rb test/jobs/cron/sync_jobs_test.rb test/services/remote_jobs_repository_test.rb
```

Rails validation is blocked in the current workspace: required gems are missing and
Docker is stopped. PostgreSQL filtering, ActiveAdmin rendering, real callbacks,
remote database writes, and live Upwork authorization remain unverified. Coverage of
the changed ActiveAdmin configuration is unresolved. The existing Fortex source and
coverage checks are `true` placeholders, not documentation or coverage evidence;
use the focused runner above, then complete Rails/UI checks in a prepared environment.
There is no repository-owned source-documentation validator to run.

## Applicant and interview activity extension

The job detail page also displays **Total applicants** from the existing search
payload's `totalApplicants`, and **Invited to interview** from
`activityStat.jobActivity.totalInvitedToInterview`. Invitations do not prove an
interview has started or finished. Applicant counts are API snapshots, not a promise
of matching the public site's proposal ranges or the current user's own proposals.

Extend the same JobActivity request, with no additional request per job. Its return
contract is `{ hires: Integer-or-nil, interviews: Integer-or-nil }`, or nil for
an unavailable response. Each field is independently validated as a nonnegative
integer. Keep `job_hires_count` unchanged in stored payloads and add
`job_interviews_count`; the remote mirror already transports the JSON payload.
Update API and worker together. No schema migration is required.

Acceptance scenarios:

- Given applicants 155 and interview invitations 3, display 155 and 3 on details.
- Given actual zero counts, display 0 rather than Unknown.
- Given missing, string, negative, or fractional counts, display Unknown.
- Given valid hires but missing interviews (or vice versa) in a successful response,
  retain the valid metric independently; GraphQL errors retain the conservative
  unavailable-response behavior.
- Given an activity request failure, keep the applicant count from search results
  and mark hiring/interview activity Unknown.
- Given repeated tags for one job, fetch activity once and mirror both metrics.

Existing synchronized applicants can display immediately after deployment. Interview
counts appear after a successful synchronization with API access; older records
remain Unknown. This extension does not claim real API access or UI validation.

### Extension verification

The new request regression first failed because `totalInvitedToInterview` was absent
from the GraphQL selection. `bin/check-job-hiring` now passes **13 tests / 226
assertions**, including independent partial counts, genuine zero, invalid/missing
counts, and mirrored applicant/interview values. Coverage: changed model activity
methods **96.97%**, API adapter **100%**, worker **94.29%**. Ruby syntax and whitespace
checks pass. The previously documented Rails/PostgreSQL/ActiveAdmin and live API
validation limits still apply; no production deployment or data modification occurred.
