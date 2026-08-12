require "test_helper"

## Verifies the jobs-only PostgreSQL persistence contract without external network access.
class RemoteJobsRepositoryTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  ## Captures SQL calls and returns controlled schema metadata.
  class FakeConnection
    ## SQL operations captured for contract assertions.
    attr_reader :exec_calls, :exec_params_calls

    ## Creates a fake PostgreSQL connection with a declared remote column set.
    #
    # Parameters:
    # - columns: Remote jobs column names returned during compatibility validation.
    #
    # Returns:
    # - A connection fake that records SQL operations.
    def initialize(columns:)
      @columns = columns
      @exec_calls = []
      @exec_params_calls = []
      @closed = false
    end

    ## Records non-parameterized schema SQL.
    #
    # Parameters:
    # - sql: Static schema statement issued by the repository.
    #
    # Returns:
    # - An empty result because DDL rows are not consumed.
    def exec(sql)
      @exec_calls << sql
      []
    end

    ## Records parameterized SQL and supplies schema metadata when requested.
    #
    # Parameters:
    # - sql: Parameterized query issued by the repository.
    # - values: Bound values kept separate from SQL text.
    #
    # Returns:
    # - Column metadata for compatibility queries, otherwise an empty result.
    def exec_params(sql, values)
      @exec_params_calls << [sql, values]
      return @columns.map { |column| { "column_name" => column } } if sql.include?("information_schema.columns")

      []
    end

    ## Marks the fake connection as closed.
    #
    # Returns:
    # - nil.
    def finish
      @closed = true
    end

    ## Reports whether the fake connection has been closed.
    #
    # Returns:
    # - true after `finish`, otherwise false.
    def finished?
      @closed
    end
  end

  ## Verifies idempotent jobs-only DDL and bound-value upsert behavior.
  test "ensures jobs schema and upserts only job attributes" do
    connection = FakeConnection.new(columns: RemoteJobsRepository::REMOTE_COLUMNS)
    repository = RemoteJobsRepository.new(connection)
    job = Job.new(
      upwork_job_id: "remote-job-1",
      data: { "id" => "remote-job-1" },
      created_at: Time.zone.parse("2026-08-12 10:00:00"),
      updated_at: Time.zone.parse("2026-08-12 10:00:00")
    )

    repository.ensure_schema!
    repository.upsert!(job)

    schema_sql = connection.exec_calls.join("\n")
    upsert_sql, values = connection.exec_params_calls.last
    assert_includes schema_sql, "CREATE TABLE IF NOT EXISTS public.jobs"
    assert_includes schema_sql, "CREATE UNIQUE INDEX IF NOT EXISTS"
    assert_includes upsert_sql, "ON CONFLICT (upwork_job_id) DO UPDATE"
    assert_equal RemoteJobsRepository::REMOTE_COLUMNS.length, values.length
    refute_match(/(?:tags|job_tags|users|proposals|oauth_credentials)/, schema_sql + upsert_sql)
  end

  ## Verifies that incompatible existing schemas fail without alteration SQL.
  test "rejects an incompatible existing jobs table" do
    connection = FakeConnection.new(columns: ["id", "upwork_job_id"])
    repository = RemoteJobsRepository.new(connection)

    assert_raises(RemoteJobsRepository::SchemaError) { repository.ensure_schema! }
    assert_empty connection.exec_params_calls.drop(1)
  end

  ## Verifies configuration validation occurs before PostgreSQL connection setup.
  test "rejects missing remote database configuration" do
    assert_raises(RemoteJobsRepository::ConfigurationError) do
      RemoteJobsRepository.from_env({})
    end
  end
end
