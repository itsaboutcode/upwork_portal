# Upwork Dashboard (Rails)

This app is a Rails 7.2.1 application that provides an ActiveAdmin dashboard and synchronizes jobs/proposals via Upwork API.

## 1) What you need

- Ruby: `3.1.2`
- PostgreSQL (database)
- Redis (for Sidekiq)
- Docker (optional but recommended for production-style run)
- A working internet connection (for gem download and Upwork OAuth flow)

## 2) Quick run overview

The app can run in:

- Local development using host Ruby (`./bin/rails server`) with your local PostgreSQL/Redis.
- Production-style self-contained container run using `docker compose` (`docker-entrypoint` runs `bundle exec rails db:prepare` automatically for the web process).

## 3) Environment variables

Create a `.env` file for local/dev (it is ignored by git by default), or set variables in container/systemd.

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

- The `.env` file is ignored via `.gitignore`; keep secrets out of git.
Compose defaults are:
- `DATABASE_HOST=db`
- `DATABASE_USERNAME=upwork`
- `DATABASE_PASSWORD=upwork_local_postgres`
- `REDIS_URL=redis://redis:6379/0`

- In production-like runs, `db:prepare` does not run `db:seed` automatically. Run seeds manually when needed.

## 4) Development mode (host Ruby + local DB)

1. Install gems

```bash
bundle install
```

2. Set environment variables and database credentials

```bash
export DATABASE_HOST=localhost
export DATABASE_USERNAME=upwork
export DATABASE_PASSWORD=upwork_local_postgres
export DATABASE_URL= # optional if using DATABASE_* settings
```

3. Prepare DB

```bash
bin/rails db:prepare
```

4. Create admin/user seed (development only has default password fallback)

```bash
bundle exec rails db:seed
```

5. Start app

```bash
./bin/rails server
```

App routes:

- `http://localhost:3000/` → redirects to `/admin`
- `http://localhost:3000/admin` → ActiveAdmin login/dashboard
- `http://localhost:3000/sidekiq` → Sidekiq web UI

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

Example `env` file:

```bash
RAILS_ENV=production
DATABASE_HOST=db
DATABASE_USERNAME=upwork
DATABASE_PASSWORD=upwork_local_postgres
REDIS_URL=redis://redis:6379/0
BASE_URL=http://localhost:3000
SECRET_KEY_BASE=your_secret_key_base
UPWORK_CLIENT_ID=your_upwork_client_id
UPWORK_CLIENT_SECRET=your_upwork_client_secret
ADMIN_SEED_EMAIL=admin@example.com
ADMIN_SEED_PASSWORD=your_admin_password
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
