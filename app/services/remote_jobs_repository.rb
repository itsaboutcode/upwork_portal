require "json"
require "pg"

## Persists normalized jobs to the separately configured jobs-only PostgreSQL database.
class RemoteJobsRepository
  ## Job attributes permitted to cross the remote persistence boundary.
  REMOTE_COLUMNS = %w[
    data created_at updated_at upwork_job_id applied published_date_time enterprise
    total_hires total_spent verification_status hired team_name team_type country
  ].freeze

  ## Raised when required remote database configuration is absent or invalid.
  class ConfigurationError < StandardError; end

  ## Raised when an existing remote jobs table cannot satisfy the mirror contract.
  class SchemaError < StandardError; end

  ## Idempotent jobs-only table bootstrap statement.
  CREATE_TABLE_SQL = <<~SQL.freeze
    CREATE TABLE IF NOT EXISTS public.jobs (
      id bigserial PRIMARY KEY,
      data jsonb,
      created_at timestamp without time zone NOT NULL,
      updated_at timestamp without time zone NOT NULL,
      upwork_job_id varchar NOT NULL,
      applied boolean DEFAULT false,
      published_date_time timestamp without time zone,
      enterprise boolean,
      total_hires integer,
      total_spent numeric,
      verification_status boolean DEFAULT false,
      hired boolean DEFAULT false,
      team_name varchar,
      team_type varchar,
      country varchar
    )
  SQL

  ## Idempotent uniqueness enforcement for remote Upwork job identifiers.
  CREATE_INDEX_SQL = <<~SQL.freeze
    CREATE UNIQUE INDEX IF NOT EXISTS index_remote_jobs_on_upwork_job_id
    ON public.jobs (upwork_job_id)
  SQL

  ## Parameterized metadata query used to reject incompatible existing tables.
  COLUMN_QUERY_SQL = <<~SQL.freeze
    SELECT column_name
    FROM information_schema.columns
    WHERE table_schema = $1 AND table_name = $2
  SQL

  ## Parameterized statement that inserts or refreshes one remote job row.
  UPSERT_SQL = <<~SQL.freeze
    INSERT INTO public.jobs (
      data, created_at, updated_at, upwork_job_id, applied, published_date_time,
      enterprise, total_hires, total_spent, verification_status, hired,
      team_name, team_type, country
    ) VALUES (
      $1::jsonb, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14
    )
    ON CONFLICT (upwork_job_id) DO UPDATE SET
      data = EXCLUDED.data,
      updated_at = EXCLUDED.updated_at,
      applied = EXCLUDED.applied,
      published_date_time = EXCLUDED.published_date_time,
      enterprise = EXCLUDED.enterprise,
      total_hires = EXCLUDED.total_hires,
      total_spent = EXCLUDED.total_spent,
      verification_status = EXCLUDED.verification_status,
      hired = EXCLUDED.hired,
      team_name = EXCLUDED.team_name,
      team_type = EXCLUDED.team_type,
      country = EXCLUDED.country
  SQL

  ## Builds a repository from environment-only connection configuration.
  #
  # Parameters:
  # - env: Environment-like key/value source containing `REMOTE_JOBS_DATABASE_*` settings.
  #
  # Returns:
  # - A connected RemoteJobsRepository.
  #
  # Errors:
  # - ConfigurationError when a required setting or numeric port is invalid.
  # - PG::Error when PostgreSQL cannot establish the configured TLS connection.
  #
  # Notes:
  # - Credentials are passed directly to libpq and are never included in application logs.
  def self.from_env(env = ENV)
    settings = {
      host: env["REMOTE_JOBS_DATABASE_HOST"],
      port: env.fetch("REMOTE_JOBS_DATABASE_PORT", "5432"),
      dbname: env["REMOTE_JOBS_DATABASE_NAME"],
      user: env["REMOTE_JOBS_DATABASE_USERNAME"],
      password: env["REMOTE_JOBS_DATABASE_PASSWORD"],
      sslmode: env.fetch("REMOTE_JOBS_DATABASE_SSLMODE", "require"),
      connect_timeout: 5
    }
    missing = settings.slice(:host, :dbname, :user, :password).filter_map do |key, value|
      key if value.blank?
    end
    raise ConfigurationError, "Missing remote jobs database configuration: #{missing.join(', ')}" if missing.any?

    settings[:port] = Integer(settings[:port], 10)
    new(PG.connect(**settings))
  rescue ArgumentError
    raise ConfigurationError, "REMOTE_JOBS_DATABASE_PORT must be a valid integer"
  end

  ## Creates a repository around a PostgreSQL-compatible connection.
  #
  # Parameters:
  # - connection: Object implementing `exec`, `exec_params`, `finish`, and `finished?`.
  #
  # Returns:
  # - A repository using the supplied connection.
  def initialize(connection)
    @connection = connection
  end

  ## Creates the jobs-only schema when absent and validates compatibility before indexing.
  #
  # Returns:
  # - true after the remote jobs table and unique index satisfy the contract.
  #
  # Errors:
  # - SchemaError when an existing table lacks required job columns.
  # - PG::Error when DDL or metadata inspection fails.
  #
  # Notes:
  # - The operation is idempotent and never drops, truncates, or alters an existing table.
  def ensure_schema!
    @connection.exec(CREATE_TABLE_SQL)
    result = @connection.exec_params(COLUMN_QUERY_SQL, %w[public jobs])
    existing_columns = result.map { |row| row.fetch("column_name") }
    missing_columns = REMOTE_COLUMNS - existing_columns
    if missing_columns.any?
      raise SchemaError, "Remote jobs table is missing required columns: #{missing_columns.join(', ')}"
    end

    @connection.exec(CREATE_INDEX_SQL)
    true
  end

  ## Idempotently mirrors one persisted local job by its Upwork identifier.
  #
  # Parameters:
  # - job: Persisted local Job whose normalized attributes are copied remotely.
  #
  # Returns:
  # - The PostgreSQL command result for the upsert.
  #
  # Errors:
  # - PG::Error when the parameterized remote write fails.
  #
  # Notes:
  # - Only fields declared in REMOTE_COLUMNS cross the external database boundary.
  def upsert!(job)
    values = REMOTE_COLUMNS.map do |column|
      value = job.public_send(column)
      column == "data" ? JSON.generate(value) : value
    end
    @connection.exec_params(UPSERT_SQL, values)
  end

  ## Releases the remote PostgreSQL connection when open.
  #
  # Returns:
  # - nil when already closed, otherwise the connection's finish result.
  def close
    return if @connection.finished?

    @connection.finish
  end
end
