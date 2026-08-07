# Upwork Dashboard (Rails)

This app is a Rails 7.2.1 application that provides an ActiveAdmin dashboard and synchronizes jobs/proposals via Upwork API.

## 1) What you need

- Docker Engine + Docker Compose (runtime + local PostgreSQL/Redis are provided by compose)
- Git (to clone and manage the project)
- A working internet connection (for image/gem layers and Upwork OAuth flow)

## 2) Quick run overview

The app can run in:

- Recommended default: self-contained container run using `docker compose` (`docker-entrypoint` runs `bundle exec rails db:prepare` automatically for the web process).

## 3) Environment variables

Copy `.env.example` to `.env` and set values for Docker runs, then keep real secrets out of git.

Required app variables:

- `DATABASE_HOST`
- `DATABASE_USERNAME`
- `DATABASE_PASSWORD`
- `REDIS_URL`

Upwork/OAuth variables:

- `BASE_URL` (for redirects and asset host, e.g. `http://localhost:3000` locally or your public domain)
- `UPWORK_CLIENT_ID`
- `UPWORK_CLIENT_SECRET`

Admin bootstrap variables:

- `ADMIN_SEED_EMAIL` (optional, defaults to `admin@example.com`)
- `ADMIN_SEED_PASSWORD` (required in production for seed execution)

Notes:

Compose defaults are:
- `DATABASE_HOST=db`
- `DATABASE_USERNAME=upwork`
- `DATABASE_PASSWORD=upwork_local_postgres`
- `REDIS_URL=redis://redis:6379/0`

- In production-like runs, `db:prepare` does not run `db:seed` automatically. Run seeds manually when needed.

## 5) Production mode (self-contained docker compose)

This mode uses the repository's local containers and does not require fortex infra:

- `db` container (PostgreSQL) runs with `POSTGRES_DB=upwork_production`.
- `redis` container runs Redis.
- `app` container runs Rails.
- `sidekiq` container runs background jobs.

### First-run behavior

On first run, Postgres initializes `upwork_production` on first startup (if it does not exist).
The Rails web container then runs database bootstrap automatically:

- `bin/docker-entrypoint` runs `rails db:prepare` before `./bin/rails server`.
- `db:prepare` creates the database if needed and applies pending migrations.

If startup races occur, restart the services after external services are healthy:

```bash
docker compose up -d
docker compose restart app sidekiq
```

1. Build and start the full stack

```bash
docker compose up -d --build
```

2. Open app

- `http://localhost:3000`

3. Run one-off setup command if needed

```bash
docker compose run --rm app bundle exec rails db:seed
```

## 6) Recommended .env file for containerized runs

Use this file as source of truth:

```bash
cp .env.example .env
```

Use with:

```bash
docker compose --env-file ./.env up -d --build
```

## 7) Upwork callback URL

Why this is required:

- The OAuth provider returns user authorization result to `BASE_URL + /auth/upwork/callback`.
- That exact URL must be allowed in Upwork app settings, including scheme, host, and path.

Set in Upwork developer app:

- `http://<your-domain-or-host>/auth/upwork/callback`

If running locally:

- `http://localhost:3000/auth/upwork/callback`

## 8) Start Sidekiq worker

Background jobs are scheduled through Sidekiq and Sidekiq Scheduler.

```bash
bundle exec sidekiq -C config/sidekiq.yml
```

Or in Docker with a separate worker container using the same environment variables as the app.
Running `docker compose up -d --build` starts this worker as the `sidekiq` service automatically.

## 9) Useful legacy system commands (optional)

If you deploy with systemd:

```bash
sudo systemctl status rails_app
sudo systemctl restart rails_app
sudo systemctl restart sidekiq
sudo journalctl -u rails_app -f
sudo journalctl -u sidekiq -f
sudo systemctl status redis
```

## 10) Health and common checks

- App container listens on port `3000`
- DB connection: ensure `db` is reachable and credentials match
- Redis connection: ensure `REDIS_URL` is reachable
- Visit `/admin` after login; default seeder email in development is `admin@example.com` and password is `password`
- If login and OAuth fail, verify:
  - `BASE_URL`
  - upwork callback URL
  - `UPWORK_CLIENT_ID`
  - `UPWORK_CLIENT_SECRET`
