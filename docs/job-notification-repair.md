# Repair oversized job notifications

## Start here: what these words mean

A **database** (often shortened to **DB**) is where your application keeps its
saved information. Think of it as a set of spreadsheets. **PostgreSQL** is the
software managing those spreadsheets. A **table** is one spreadsheet, and a
**row** is one saved record. Here, the `jobs` table stores jobs, one row per job.
`public` is the folder-like grouping containing that table, so `public.jobs`
means “the jobs table in the public group.”

A **trigger** is an automatic database action. Your existing trigger runs when
a job is inserted and calls a **function**, a named set of instructions called
`notify_job_insert()`. That function sends a notification on `jobs_channel`.
A **listener** is another application waiting for these notifications.

Currently the notification contains the entire job. Some jobs are too large
for a notification, so PostgreSQL rejects the save. This repair changes the
message to something like `{"id":123}`, meaning “job number 123 was saved;
look it up.” The full job still lives in the database.

| File | Purpose |
| --- | --- |
| `db/operations/repair_job_notifications.sql` | Instructions for PostgreSQL to change the notification function. |
| This guide | Instructions for you to apply, check, and undo that change. |
| `notify_job_insert.before.sql` | A backup you create below, containing the old function so you can restore it. It is not a backup of your job data. |

The repair file does not run when you open it, start Rails, or run Rails
migrations. You apply it once; afterward the existing trigger works
automatically when jobs are inserted.

## Before typing commands

The commands below are for a **terminal**, the window where you type commands
on your server. Connect to your server using your usual SSH method, then open
the project directory. The repair file must be present there. Commands shown
as `sh` go in the terminal; snippets shown as `sql` illustrate database
instructions and are not standalone terminal commands.

You need `psql`, PostgreSQL's command-line client, on the server:

```sh
psql --version
ls db/operations/repair_job_notifications.sql
```

The first command should print a PostgreSQL version. The second should print
the file path. If you see `command not found` or `No such file or directory`,
stop and arrange the missing client or file before continuing.

Your project uses two database connections: the local Rails database and a
separate database receiving copied jobs. We suspect the second database, but
must confirm which one contains the failing trigger. These settings describe
the remote connection:

| Setting | Meaning |
| --- | --- |
| `REMOTE_JOBS_DATABASE_HOST` | Address of the computer hosting the database. |
| `REMOTE_JOBS_DATABASE_PORT` | Connection number, usually `5432`. |
| `REMOTE_JOBS_DATABASE_NAME` | Name of the database on that computer. |
| `REMOTE_JOBS_DATABASE_USERNAME` | Account used to connect. |
| `REMOTE_JOBS_DATABASE_PASSWORD` | That account's private password. |
| `REMOTE_JOBS_DATABASE_SSLMODE` | How the connection uses encryption; this project defaults to `require`. |

Ask the server administrator for these values if you do not know them. Do not
paste the password into chat. `psql` does not automatically read your project's
`.env` file or translate `REMOTE_JOBS_DATABASE_*` into its own settings.

In the same terminal where you will run the repair, replace the example text
below with the confirmed connection details. Keep the quotation marks. These
`export` commands tell subsequent `psql` commands which database to use; they
do not change the database. Use the confirmed port and encryption setting.

```sh
export PGHOST="YOUR_DATABASE_HOST"
export PGPORT="5432"
export PGDATABASE="YOUR_DATABASE_NAME"
export PGUSER="YOUR_DATABASE_USERNAME"
export PGSSLMODE="require"
```

The commands below use `-W` to ask for the password. Password characters may
not appear while typing; that is normal. These instructions assume direct
access from the server to the database. If the address is a Docker service
name such as `db`, it may only work inside the Docker network; do not guess a
different database address.

**Before applying the repair, the listener must be updated.** Its developer
must make it read the ID and fetch that job's full details. Otherwise the
database save can succeed while the receiving application stops working.
Neither that listener nor the existing trigger is defined in this repository.

## Cause and contract

The reported trigger calls `pg_notify('jobs_channel', row_to_json(NEW)::text)`.
PostgreSQL notification payloads must be shorter than 8,000 bytes in the default
configuration. A large job row causes the write to fail, aborting synchronization.
See [PostgreSQL NOTIFY](https://www.postgresql.org/docs/current/sql-notify.html).

The repair sends `{"id":123}` on the same channel. The full job stays in
`public.jobs`; the consumer retrieves it with a parameterized query:

```sql
SELECT * FROM public.jobs WHERE id = $1;
```

Use the ID from the database receiving the notification, not the local Rails ID
or Upwork ID. No new application abstraction is needed: this is a database
trigger and listener payload contract. The trigger and listener are not defined
in this repository. The remote mirror is a likely source, but database ownership
must be confirmed from the catalogs before applying anything.

## Inspect and back up

First confirm the database and trigger. This command only reads database
information; it does not change anything:

```sh
psql -X -W -v ON_ERROR_STOP=1 -c "SELECT current_database(), n.nspname AS table_schema, c.relname AS table_name, t.tgname, pg_get_triggerdef(t.oid), p.oid::regprocedure AS function FROM pg_trigger t JOIN pg_class c ON c.oid = t.tgrelid JOIN pg_namespace n ON n.oid = c.relnamespace JOIN pg_proc p ON p.oid = t.tgfoid WHERE NOT t.tgisinternal AND p.proname = 'notify_job_insert';"
```

Look for the expected database name, table schema `public`, table name `jobs`,
and function `public.notify_job_insert()` (PostgreSQL may omit `public` in its
display). The trigger definition should include `AFTER INSERT` and
`FOR EACH ROW`. If no rows appear, or the details differ, stop and have the
database administrator review them. A database can contain other triggers
using this same function; all of them need review before replacement.

Next save the old function to a backup file in your home directory:

```sh
psql -X -W -v ON_ERROR_STOP=1 -At -c "SELECT pg_get_functiondef('public.notify_job_insert()'::regprocedure);" > "$HOME/notify_job_insert.before.sql"
cat "$HOME/notify_job_insert.before.sql"
```

`>` saves the output to a file. It overwrites a file with the same name, so
keep an existing backup under another name before repeating this command.
`cat` displays the saved file. It should contain a complete
`CREATE OR REPLACE FUNCTION` definition, including the original full-row
notification. If the backup command reports an error or the file is empty,
stop. Do not apply the repair without a usable backup.

Confirm the backup contains the complete original function definition. Keep it
outside the repository. Inspect other triggers and other tables using this
function: changing a shared function changes all its callers. If the schema,
timing, permissions, or function settings differ from the supported contract,
review the actual definition and adapt the repair before deployment.

## Rollout

1. Identify every consumer of `jobs_channel`. Deploy support for the compact
   ID payload first. During transition, support old full-row payloads as needed.
   Fetch the committed row by its ID with existing access controls. A missing
   row should be handled as a deleted or unavailable job, without a crash.
2. Validate in a disposable database using synthetic data: reproduce the error
   with the original trigger and a JSON row exceeding 8 KB; apply the repair;
   confirm insertion succeeds, data remains complete, and the notification ID
   fetches that exact row. Confirm a rolled-back write produces no notification.
3. After approval for the external database change, apply the repair:

   ```sh
   psql -X -W -v ON_ERROR_STOP=1 -f db/operations/repair_job_notifications.sql
   ```

   This is the command that changes the database. `-f` means “run the
   instructions in this file.” Expected output ends with:

   ```text
   DO
   CREATE FUNCTION
   COMMIT
   ```

   `COMMIT` means PostgreSQL saved the change. If an `ERROR` appears, stop
   and review its message. `ON_ERROR_STOP=1` stops on the first error;
   the script's transaction ensures its changes are not partly saved.

4. Observe the next scheduled `Cron::SyncJobs` run or explicitly enqueue one
   through the authorized operator workflow. Check worker success, remote row
   persistence, and listener processing. The worker uses `retry: false`, so
   old failed runs do not automatically retry. Existing remote upserts use
   `upwork_job_id` for deduplication.

   In Sidekiq, check for new failures after the change, rather than expecting
   old failed entries to disappear. Ask the listener's operator to confirm
   that new jobs also reach the receiving application. Both checks matter.

## How to read the SQL file

Lines starting with `--` are explanatory comments, not instructions.

| Section | What it does |
| --- | --- |
| `BEGIN` | Starts a transaction: a group of changes saved together. |
| `SET LOCAL` | Limits how long the repair waits for database locks and statements. These limits apply only to this transaction. |
| `DO ...` | Checks that an enabled, compatible trigger already exists. The catalog queries inspect PostgreSQL's own records describing functions and triggers. |
| `RAISE EXCEPTION` | Stops the repair if those checks fail. It does not create a missing trigger. |
| `CREATE OR REPLACE FUNCTION` | Replaces the existing notification function. The existing trigger continues calling it. |
| `NEW.id` | The database ID of the job being inserted. |
| `json_build_object` | Builds the small message containing that ID. |
| `pg_notify` | Sends that message on `jobs_channel`, delivered after the job's transaction commits. |
| `RETURN NEW` | Keeps the function's expected trigger return value. |
| `COMMIT` | Saves the repair when all earlier steps have succeeded. |

Command options used in this guide: `-X` ignores personal `psql` startup
settings, `-W` prompts for a password, `-c` runs the quoted database command,
and `-At` saves plain output without table formatting. These options make
the backup and repair commands predictable.

The repair is transactional and uses short lock/statement timeouts. It refuses
to create a missing trigger or replace a function with privileged execution or
custom settings. It preserves the trigger attachment and does not truncate
job data, disable notifications, or run automatically during Rails startup.
`NOTIFY` is a signal, not a durable queue; existing listener catch-up behavior
must continue to handle disconnections.

## Rollback

Restore the saved function while the listener still supports both payloads:

```sh
psql -X -W -v ON_ERROR_STOP=1 --single-transaction -f "$HOME/notify_job_insert.before.sql"
```

Use the same connection settings as for the repair. This command changes the
database back to the saved function. `--single-transaction` makes the restore
an all-or-nothing operation. If it reports an error, stop and ask the database
administrator to inspect it. Do not roll back the listener's compatibility
support before the function has been restored successfully.

Rollback restores the original behavior, including the failure for large jobs.
No rows are deleted by repair or rollback.

## Verification evidence (2026-10-08)

In a disposable PostgreSQL 18 database, using synthetic data and no production
connection:

- Original full-row trigger: a 12,000-byte description failed with
  `payload string too long`.
- Repair: the same insert succeeded and delivered `{"id" : 2}` on
  `jobs_channel`; querying that ID returned all 12,000 description bytes.
- Transaction rollback: the inserted row was absent and no notification was
  delivered; the committed row count stayed at one.
- Disabled trigger: the repair refused to proceed with its expected-contract
  exception, and its transaction rolled back.

SQL syntax and the supported upgrade path were exercised by PostgreSQL itself.
Source documentation was reviewed for the guard block and trigger function.
No repository-owned SQL documentation or coverage checker exists. Automated
test generation is blocked because the configured `gpt-5.6-luna` specialist is
unavailable; no substitute agent was used. SQL line coverage was not measured.
Rails migrations and application behavior were not changed. Actual listener
integration, production PostgreSQL version, shared-function callers, and live
rollout remain unverified. These observations prove the isolated repair, not
that the reported production failure has been resolved.
