# Upwork Dashboard (Rails)

Rails 7.2.1 dashboard built with ActiveAdmin, with Upwork OAuth and scheduled job/proposal synchronization. Docker Compose provides Rails, PostgreSQL, Redis, Nginx, and Sidekiq.

## Start here

1. [Prerequisites and configuration](#1-prerequisites-and-configuration)
2. [Run locally with Docker](#2-run-locally-with-docker)
3. [Deploy to production](#3-deploy-to-production)
4. [Enable synchronization](#4-enable-synchronization)
5. [Operations and troubleshooting](#5-operations-and-troubleshooting)
6. [Backups and recovery](#6-backups-and-recovery)
7. [Destructive local reset](#7-destructive-local-reset)
8. [Development and validation boundaries](#8-development-and-validation-boundaries)

Both Docker walkthroughs run Rails in **production mode**, including on your laptop. Local Docker use is not a Rails development/hot-reload setup. Start the dashboard first, then start Sidekiq after configuring its integrations.

## 1. Prerequisites and configuration

Install Git and Docker Engine with the Docker Compose plugin (or Docker Desktop). Internet access is needed to download images and gems. Port 80 must be available; production HTTPS also requires port 443, a domain, and a valid certificate.

Clone or extract the project, then open a terminal in the repository root containing `docker-compose.yml`:

```bash
docker --version
docker compose version
```

On a **new installation**, create the configuration before starting containers:

```bash
cp .env.example .env
```

Do not copy over an existing configured `.env`. Keep it and real credentials out of Git. Generate a session secret using the Dockerfile's Ruby version:

```bash
docker run --rm ruby:3.3.5-slim ruby -rsecurerandom -e 'puts SecureRandom.hex(64)'
```

Paste the output into `SECRET_KEY_BASE` in `.env`, and replace template passwords before startup.

| Variable | Meaning and setup |
| --- | --- |
| `SECRET_KEY_BASE` | Generated session secret; keep it stable across app and worker recreations. Do not use the Compose fallback `changeme`. |
| `BASE_URL` | Browser-facing origin without a trailing slash, such as `http://localhost`; used for OAuth and asset URLs. |
| `HOST` | Hostname or IP only, without scheme or path; added to the production host allowlist. |
| `SERVER_PUBLIC_IP` | Optional additional allowed IP; add this variable to `.env` when needed. |
| `ALLOWED_HOSTS` | Optional comma-separated additional hosts; add it to `.env` when needed. |
| `DATABASE_USERNAME`, `DATABASE_PASSWORD` | Compose PostgreSQL credentials. Use a strong production password. Editing these after initialization does not change the existing database role's password. |
| `ADMIN_SEED_EMAIL` | Defaults to `admin@example.com`. The OAuth Credentials page currently permits only this exact email, even if another account is an administrator. |
| `ADMIN_SEED_PASSWORD` | Set before seeding. Without it, production seeding skips administrator creation. |
| `NORMAL_SEED_EMAIL`, `NORMAL_SEED_PASSWORD` | Optional normal account; set both to create it. |
| `UPWORK_CLIENT_ID`, `UPWORK_CLIENT_SECRET` | Real application credentials required for OAuth and synchronization, not for opening the dashboard. |
| `REMOTE_JOBS_DATABASE_*` | Required for jobs synchronization; see section 4. |

Compose explicitly sets `RAILS_ENV=production`, `DATABASE_HOST=db`, and `REDIS_URL=redis://redis:6379/0` for app and worker. Editing those entries in `.env` does not override Compose. PostgreSQL and Redis have no published host ports.

The template also contains Rails tuning and Upwork retry/rate-limit variables. Compose does not forward every template variable. Check `docker-compose.yml` before assuming a setting reaches a container; `.env` is excluded from the Docker image.

## 2. Run locally with Docker

Complete section 1 with:

```dotenv
BASE_URL=http://localhost
HOST=localhost
```

### Build and start

```bash
docker compose config --quiet
docker compose up -d --build app nginx
docker compose ps
docker compose logs --tail=100 app nginx
```

This also starts PostgreSQL and Redis dependencies. The app entrypoint runs `rails db:prepare` before Rails starts: it initializes an uninitialized database or applies pending migrations. Rails can load seeds during initial preparation; it does not routinely reseed an initialized database on every restart.

Wait for Rails to finish preparation and start serving. PostgreSQL and Redis should report healthy; app and Nginx should remain running. App/Nginx have no Compose healthchecks, so verify HTTP separately.

### Establish the account and sign in

Explicitly seed to ensure the configured accounts exist:

```bash
docker compose exec app bundle exec rails db:seed
```

Seeding **reconciles existing seeded accounts**, including passwords and roles; run it deliberately. Output saying an account was skipped does not establish a login.

Open [http://localhost/users/sign_in](http://localhost/users/sign_in), using `ADMIN_SEED_EMAIL` and `ADMIN_SEED_PASSWORD`. Login should open `/admin`. Self-service signup is disabled.

```bash
curl -I http://localhost/
```

The root route should return HTTP 302 to `/admin`. Also verify the dashboard in the browser after login.

Continue to section 4 before starting synchronization. Running `docker compose up -d --build` without service names also starts Sidekiq and its scheduled jobs.

## 3. Deploy to production

Complete section 1 and the production settings below before starting the public application.

### Public URL and allowed hosts

For the current HTTP server:

```dotenv
BASE_URL=http://159.89.231.140
HOST=159.89.231.140
SERVER_PUBLIC_IP=159.89.231.140
```

For a domain with HTTPS:

```dotenv
BASE_URL=https://dashboard.example.com
HOST=dashboard.example.com
SERVER_PUBLIC_IP=159.89.231.140
```

Replace the example domain with yours and point its DNS record to the server. `BASE_URL` does not itself allow a host. Production authorization uses `HOST`, `SERVER_PUBLIC_IP`, and `ALLOWED_HOSTS`, plus explicit entries in `config/environments/production.rb`. An unlisted host can cause HTTP 403.

### HTTPS configuration required

The checked-in stack serves **HTTP only**. Configure HTTPS before transmitting production credentials. The commented Nginx example needs these corrections; simply uncommenting it is insufficient:

1. Enable the Nginx `443:443` port and certificate mount `./nginx/certs:/mnt/nginx-certs:ro` in `docker-compose.yml`.
2. Before placing certificates in `nginx/certs`, exclude that directory from Git and the Docker build context. The current `.dockerignore` does not exclude it. Then supply a valid certificate chain and private key.
3. Enable the HTTPS block in `nginx/default.conf`, set `server_name` to your domain, and use certificate paths `/mnt/nginx-certs/fullchain.pem` and `/mnt/nginx-certs/privkey.pem` to match the mount.
4. Replace `proxy_pass http://upwork_dashboard_app` with the existing HTTP block's Docker-resolved pattern: `set $upstream_app http://app:3000;` followed by `proxy_pass $upstream_app;`. Preserve the forwarded headers.
5. Configure HTTP-to-HTTPS redirection for your certificate renewal method, and arrange renewal and Nginx reloads.
6. Set the HTTPS `BASE_URL` and matching host allowlist. Rails currently sets `force_ssl = false`; review HTTPS enforcement and secure cookies for the chosen TLS termination architecture.

These are configuration changes still required, not changes already applied by this guide. If an external proxy terminates TLS, configure trusted forwarding and restrict direct backend access for that architecture instead.

Allow the intended web ports through the server firewall. Do not publish PostgreSQL or Redis for browser access.

### Build, start, and verify

After completing configuration:

```bash
docker compose config --quiet
docker compose up -d --build app nginx
docker compose exec nginx nginx -t
docker compose ps
docker compose logs --tail=100 app nginx
```

Wait for Rails startup, then establish the account:

```bash
docker compose exec app bundle exec rails db:seed
```

Visit `BASE_URL`, verify the certificate when using HTTPS, and sign in at `/users/sign_in`. Verify `/admin` loads and HTTP redirects to HTTPS if configured. Complete section 4 to enable integrations.

## 4. Enable synchronization

### Authorize Upwork

Set real `UPWORK_CLIENT_ID` and `UPWORK_CLIENT_SECRET` values. Register the exact callback `BASE_URL` + `/auth/upwork/callback` in the Upwork application settings. Examples:

- Local: `http://localhost/auth/upwork/callback`
- HTTPS production: `https://dashboard.example.com/auth/upwork/callback`

After changing app environment values, recreate the app:

```bash
docker compose up -d app
```

Log in as `admin@example.com`, open OAuth Credentials, select **Sync New Upwork Account**, and complete authorization. Verify the credential appears. Create active tags for the job searches you want to synchronize.

### Configure remote job mirroring

Jobs synchronization requires a separate reachable PostgreSQL database. Set:

```dotenv
REMOTE_JOBS_DATABASE_HOST=your-database-host
REMOTE_JOBS_DATABASE_PORT=5432
REMOTE_JOBS_DATABASE_NAME=your-database-name
REMOTE_JOBS_DATABASE_USERNAME=your-database-user
REMOTE_JOBS_DATABASE_PASSWORD=replace-with-a-strong-password
REMOTE_JOBS_DATABASE_SSLMODE=require
```

Compose forwards these settings to Sidekiq. The database must exist; the worker creates `public.jobs` and its unique `upwork_job_id` index if absent. The database account needs permission to create these objects and read/write the jobs table.

Only normalized jobs are mirrored, not users, proposals, tags, tag relationships, or OAuth credentials. Missing configuration, connection errors, or an incompatible schema fail jobs synchronization. Blank settings do not silently disable mirroring. Already committed local job data remains on a remote failure. See [the mirroring specification](docs/specs/remote-job-mirroring.md).

### Start and verify Sidekiq

```bash
docker compose up -d --build sidekiq
docker compose logs --tail=100 sidekiq
```

The worker also runs `db:prepare` on startup. `config/sidekiq.yml` schedules jobs every five minutes, proposals every four hours, and token refresh daily at 01:00 in the scheduler's effective timezone. Confirm that timezone for your deployment.

Check `/sidekiq`, worker logs, and resulting dashboard records. Current permissions are:

- Dashboard, Jobs, and Tags: normal and administrator accounts.
- Proposals: administrator accounts.
- OAuth Credentials: only `admin@example.com`.
- Sidekiq: **all authenticated application users**, including normal users; queue access is not administrator-only.

## 5. Operations and troubleshooting

### Status and logs

```bash
docker compose ps
docker compose logs --tail=100 app nginx sidekiq
```

Review logs locally and redact credentials or personal data before sharing them. Full rendered Compose output can contain secrets; use `config --quiet` for validation.

| Symptom | Check |
| --- | --- |
| HTTP 403 | Compare the requested host with the production allowlist; use app/proxy logs to identify the rejecting layer. Recreate the app after environment changes. |
| HTTP 502 | Inspect app startup/database errors and the Nginx upstream. Nginx can start before Rails is ready. |
| Login fails | Use `/users/sign_in`, check seed output and credentials. Docker runs production, so development password defaults do not apply. |
| OAuth fails | Check `BASE_URL`, registered callback, client credentials, and the exact-email restriction. |
| Worker fails | Check authorization, remote database settings/connectivity/schema, and worker logs. |
| Database password edit breaks login | Existing volumes retain PostgreSQL role credentials; coordinate the database password change with app/worker configuration. |

### Updates and restarts

Back up data, review migrations, and deploy the intended source revision. For a dashboard-only installation:

```bash
docker compose up -d --build app nginx
```

For an installation with configured integrations:

```bash
docker compose up -d --build app sidekiq nginx
```

Startup can apply migrations. Plan a maintenance window where needed, then verify HTTP, login, and workers. A previous app image may not be compatible with a newly migrated database.

Environment changes require recreation with `docker compose up -d SERVICE`; `docker compose restart` alone does not apply changed Compose environment values. For a changed bind-mounted Nginx configuration:

```bash
docker compose exec nginx nginx -t
docker compose exec nginx nginx -s reload
```

Stop/start existing containers without deleting data:

```bash
docker compose stop
docker compose start
```

Host `systemctl` and `bundle exec sidekiq` commands require a separately configured native installation; they are not additional Docker setup steps.

## 6. Backups and recovery

PostgreSQL uses `postgres_data`; Redis uses `redis_data`. Keep the Compose project identity stable so redeployments select the same volumes. The app's `storage` directory is not mounted persistently: add persistent storage before relying on uploads surviving container replacement.

Create a PostgreSQL logical backup outside the repository:

```bash
backup_file="$HOME/upwork-production-$(date +%Y%m%d-%H%M%S).dump"
umask 077
docker compose exec -T db sh -c 'pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Fc' > "$backup_file"
test -s "$backup_file"
docker compose exec -T db pg_restore --list < "$backup_file"
```

Check each command's exit status. A readable archive listing is not proof of recoverability: test restoration into a separate disposable database. Store backups securely off-server and define retention. Back up the remote jobs database separately where required, along with deployment configuration, session secret, certificates, and persistent uploads. PostgreSQL dumps do not include Redis queues.

For recovery, stop writes and workers, identify the backup and compatible application revision, and rehearse restoration separately before replacing production data. Do not use local reset as production recovery. This repository does not provide automated backup, restore, or rollback tooling.

## 7. Destructive local reset

**Disposable local installations only.** This deletes local PostgreSQL and Redis volume data. Verify the local Docker context and Compose project first. Preserve your configured `.env`.

```bash
docker context show
docker compose ps
docker compose down -v
docker compose up -d --build app nginx
```

Wait for startup, then establish the account:

```bash
docker compose exec app bundle exec rails db:seed
```

Start Sidekiq separately when its integrations are configured. This reset does not delete the remote jobs database.

`rails db:reset` is also destructive: it drops and recreates the database even if its Docker volume remains. Production safeguards may block it; do not disable them as a routine setup step.

## 8. Development and validation boundaries

Docker builds use Ruby 3.3.5, while `.ruby-version` specifies 3.1.2. This guide uses Docker; native development requires a reconciled runtime, installed gems, reachable PostgreSQL/Redis, and an explicit development environment.

CI declares Brakeman, importmap audit, RuboCop, and Rails tests in `.github/workflows/ci.yml`. The source and coverage commands in `.fortex/verification.json` are `true` placeholders; they do not validate documentation, source quality, or coverage.

These instructions reflect checked-in configuration. A fresh installation, HTTPS, Upwork authorization, remote mirroring, and backup restoration must be verified in the target environment before treating a deployment as operationally validated.
