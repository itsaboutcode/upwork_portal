# Remote job mirroring

## Purpose

Mirror each successfully fetched and normalized Upwork job to a separately configured PostgreSQL database while keeping the local database authoritative.

## Scope

- Mirror only the current `jobs` columns to remote `public.jobs`.
- Create `public.jobs` and its unique `upwork_job_id` index when absent.
- Reuse a compatible existing table without destructive changes.
- Exclude tags, job-tag relationships, users, proposals, and OAuth credentials.
- Fail the current synchronization when remote persistence fails.
- Keep all remote credentials outside committed source and logs.

## Acceptance criteria

1. A locally persisted fetched job is upserted remotely by `upwork_job_id`.
2. Re-fetching a job updates its remote row without creating a duplicate.
3. An absent remote jobs table is created with the current jobs-only schema.
4. An incompatible existing remote jobs table fails safely without alteration.
5. No non-job application table or row is copied remotely.
6. Missing remote configuration fails before a connection is attempted.
7. Remote errors remain visible while committed local job data is retained for the next idempotent run.

## Test matrix

| Criterion | Test level | Evidence |
| --- | --- | --- |
| AC1, AC2 | Worker/unit | Fake repository receives the normalized local job once per fetched payload |
| AC3 | Adapter/unit | PostgreSQL adapter emits jobs-only idempotent DDL and unique index DDL |
| AC4 | Adapter/unit | Missing required columns raise a sanitized schema error |
| AC5 | Adapter/unit | DDL and upsert SQL never reference excluded tables |
| AC6 | Adapter/unit | Missing environment values raise configuration error before `PG.connect` |
| AC7 | Worker/unit | Remote upsert error propagates and repository closes |

## Operations

- Rollout configures `REMOTE_JOBS_DATABASE_*` only on Sidekiq and restarts that service.
- Rollback removes those variables and the mirror call; remote data is left untouched.
- Runtime bootstrap uses no `DROP`, `TRUNCATE`, Rails migration, or historical backfill.
- A live smoke test requires separate authorization because it changes an external database.

