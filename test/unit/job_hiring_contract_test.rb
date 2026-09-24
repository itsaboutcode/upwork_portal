# Copyright (c) 2026 Fortex Solutions. All rights reserved.
# Run independently of Rails: ruby test/unit/job_hiring_contract_test.rb.
if defined?(Rails)
  warn "Run job_hiring_contract_test.rb separately with Ruby; Rails integration tests cover persistence."
else
require "minitest/autorun"
require "coverage"
require "minitest/mock"
require "logger"
require "stringio"

# Substitutes only ActiveRecord storage and callback registration for isolated model tests.
class ApplicationRecord
  # Stores attributes at the persistence substitution boundary.
  attr_accessor :data, :applied, :published_date_time, :enterprise, :total_hires,
                :hired, :total_spent, :verification_status, :team_name, :team_type, :country

  # Accepts association declarations without opening a database connection.
  # Parameters: args - association name and options supplied by the model.
  # Returns: nil. Errors: none.
  def self.has_many(*args); end

  # Accepts callback registration; tests invoke the real callback explicitly.
  # Parameters: args - callback names supplied by the model.
  # Returns: nil. Errors: none.
  def self.before_save(*args); end

  # Accepts search declarations without loading Arel or querying the database.
  # Parameters: args - search field configuration; block - SQL expression builder.
  # Returns: nil. Errors: none.
  def self.ransacker(*args, &block); end

  # Mimics the persisted boolean predicate before the model overrides it.
  # Returns: the stored hiring flag. Errors: none.
  def hired?
    @hired
  end

  # Reads stored attributes independently of overridden readers.
  # Parameters: name - persisted attribute key.
  # Returns: the stored value. Errors: invalid attribute names raise NameError.
  def [](name)
    instance_variable_get("@#{name}")
  end
end

# Supplies Rails' blank predicate at the standard library substitution boundary.
class Object
  # Identifies absent values for model callbacks.
  # Returns: whether the receiver is false, nil, or empty. Errors: none.
  def blank?
    respond_to?(:empty?) ? !!empty? : !self
  end
end

# Supplies only external API boundaries; production activity parsing remains real.
module UpworkApis
  # Avoids credential lookup and network client construction in isolated tests.
  class Base
    # Holds the injected request transport.
    attr_accessor :graphql
  end

  # Counts limiter entries while allowing the controlled fake request to execute.
  class RateLimiter
    class << self
      # Counts rate-limiter entries observed by the assertions.
      attr_accessor :calls

      # Executes a controlled API operation under the limiter substitution.
      # Parameters: block - fake network operation to execute.
      # Returns: block result. Errors: propagates the operation's exception.
      def execute(&block)
        self.calls = (calls || 0) + 1
        block.call
      end
    end
  end
end

Coverage.start
load File.expand_path("../../app/models/job.rb", __dir__)
activity_file = File.expand_path("../../lib/upwork_apis/job_activity.rb", __dir__)
load activity_file if File.exist?(activity_file)

# Verifies hiring, applicant, and interview counts against the production model and adapter.
class JobHiringContractTest < Minitest::Test
  # Builds a model with a client whose historical hires must not affect job hiring.
  # Parameters: count - raw job-level count; present - whether the payload includes it.
  # Returns: an isolated Job. Errors: none.
  def build_job(count = nil, present: true)
    job = Job.new
    job.data = {"client" => {"totalHires" => 516}}
    job.data["job_hires_count"] = count if present
    job.hired = true
    job
  end

  # Confirms zero job hires override positive lifetime hiring and stale stored true.
  # Returns: assertion results. Errors: assertion failure if historical hires leak.
  def test_zero_hires_ignore_client_history
    job = build_job(0)
    job.send(:prefill_columns)
    assert_equal false, job.hired
    assert_equal 0, job.job_hires_count
    assert_equal false, job.hired
    assert_equal false, job.hired?
    assert_equal "No", job.hiring_status
    job.send(:prefill_columns)
    assert_equal false, job[:hired]
    assert_equal 516, job.total_hires
  end

  # Confirms verified positive counts produce a true stored and displayed status.
  # Returns: assertion results. Errors: assertion failure for inconsistent status.
  def test_positive_job_hires
    job = build_job(2)
    assert_equal 2, job.job_hires_count
    assert_equal true, job.hired
    assert_equal true, job.hired?
    assert_equal "Yes", job.hiring_status
    job.send(:prefill_columns)
    assert_equal true, job[:hired]
  end

  # Confirms missing and malformed job counts never become a known hiring status.
  # Returns: assertion results. Errors: assertion failure for invalid-data coercion.
  def test_unknown_and_invalid_counts
    [nil, -1, "2", "", 1.5, true, {}, []].each do |count|
      job = build_job(count)
      assert_nil job.job_hires_count, "count=#{count.inspect}"
      assert_nil job.hired
      assert_nil job.hired?
      assert_equal "Unknown", job.hiring_status
      job.send(:prefill_columns)
      assert_nil job[:hired]
    end
    assert_nil build_job(present: false).hired
    job = build_job
    job.data = nil
    assert_nil job.job_hires_count
    assert_nil job.hired
  end

  # Confirms admin filtering exposes verified status and hides the legacy boolean.
  # Returns: assertion results. Errors: assertion failure for an unsafe filter contract.
  def test_verified_hiring_filter_contract
    assert_includes Job.ransackable_attributes, "job_hiring_status"
    refute_includes Job.ransackable_attributes, "hired"
  end

  # Builds independent hiring and interview statistics for the requested posting.
  # Parameters: count - raw upstream hire count; id - upstream posting identifier; interviews - raw invitation count.
  # Returns: a GraphQL response hash. Errors: none.
  def response(count, id: "914", interviews: 3)
    {"data" => {"marketplaceJobPosting" => {"id" => id,
      "activityStat" => {"jobActivity" => {"totalHired" => count, "totalInvitedToInterview" => interviews}}}}}
  end

  # Executes the real adapter against a request-recording fake transport.
  # Parameters: payload - response returned by the fake; job_id - requested posting.
  # Returns: pair of parsed activity and request. Errors: adapter errors propagate.
  def fetch(payload, job_id: "914")
    assert defined?(UpworkApis::JobActivity), "JobActivity implementation is missing"
    request = nil
    transport = Object.new
    # Parameters: params - GraphQL request. Returns: controlled response. Errors: none.
    transport.define_singleton_method(:execute) { |params| request = params; payload }
    client = UpworkApis::JobActivity.new
    client.graphql = transport
    UpworkApis::RateLimiter.calls = 0
    value = client.call(job_id)
    assert_equal 1, UpworkApis::RateLimiter.calls
    [value, request]
  end

  # Confirms the operation requests job activity with a separately bound identifier.
  # Returns: assertion results. Errors: assertion failure for incorrect API binding.
  def test_activity_query_and_verified_counts
    [0, 2].each do |count|
      value, request = fetch(response(count))
      assert_match(/totalInvitedToInterview/, request.fetch("query"))
      assert_equal({hires: count, interviews: 3}, value)
      assert_match(/marketplaceJobPosting/, request.fetch("query"))
      assert_match(/activityStat/, request.fetch("query"))
      assert_match(/jobActivity/, request.fetch("query"))
      assert_match(/totalHired/, request.fetch("query"))
      assert_equal "914", request.fetch("variables").fetch("id")
    end
  end

  # Confirms inaccessible, errored, mismatched and malformed postings stay unknown.
  # Returns: assertion results. Errors: assertion failure for fabricated hiring data.
  def test_activity_unavailable_and_invalid_results
    [nil, {}, {"data" => nil}, {"data" => {"marketplaceJobPosting" => nil}},
     response(1).merge("errors" => [{"message" => "Denied"}]),
     response(1, id: "other"), {"data" => []},
     {"data" => {"marketplaceJobPosting" => "unexpected"}}].each do |payload|
      assert_nil fetch(payload).first, "payload=#{payload.inspect}"
    end
  end

  # Confirms each activity count remains independent when the other is unavailable.
  # Returns: assertion results. Errors: assertion failure for cross-field data loss.
  def test_activity_partial_counts_remain_independent
    [nil, -1, "2", 1.5, true, {}, []].each do |invalid|
      assert_equal({hires: nil, interviews: 3}, fetch(response(invalid)).first)
      assert_equal({hires: 2, interviews: nil}, fetch(response(2, interviews: invalid)).first)
    end
    assert_equal({hires: 0, interviews: 0}, fetch(response(0, interviews: 0)).first)
    assert_equal({hires: nil, interviews: nil}, fetch(response(nil, interviews: nil)).first)
  end

  # Confirms unavailable activity returns unknown counters without losing posting identity.
  # Returns: assertion results. Errors: assertion failure for fabricated activity.
  def test_activity_missing_counters
    [nil, {}].each do |activity|
      payload = response(2)
      payload["data"]["marketplaceJobPosting"]["activityStat"] = activity
      assert_equal({hires: nil, interviews: nil}, fetch(payload).first)
    end
    payload = response(2)
    payload["data"]["marketplaceJobPosting"]["activityStat"]["jobActivity"] = nil
    assert_equal({hires: nil, interviews: nil}, fetch(payload).first)
    payload["data"]["marketplaceJobPosting"]["activityStat"]["jobActivity"] = []
    assert_nil fetch(payload).first
  end

  # Confirms interview and applicant counters validate exact nonnegative integers.
  # Returns: assertion results. Errors: assertion failure for coerced or conflated counts.
  def test_interview_and_applicant_counts
    job = build_job(2)
    job.data.merge!("job_interviews_count" => 3, "totalApplicants" => 155)
    assert_equal 3, job.job_interviews_count
    assert_equal 155, job.total_applicants
    [nil, -1, "2", 1.5, true, {}, []].each do |invalid|
      job.data.merge!("job_interviews_count" => invalid, "totalApplicants" => invalid)
      assert_nil job.job_interviews_count
      assert_nil job.total_applicants
      assert_equal 2, job.job_hires_count
    end
    job.data.merge!("job_interviews_count" => 0, "totalApplicants" => 0)
    assert_equal 0, job.job_interviews_count
    assert_equal 0, job.total_applicants
    job.data = nil
    assert_nil job.job_interviews_count
    assert_nil job.total_applicants
  end

  # Confirms an absent posting ID makes no external request.
  # Returns: assertion results. Errors: any attempted API call fails this test.
  def test_activity_empty_identifier
    client = UpworkApis::JobActivity.new
    assert_nil client.call(nil)
    assert_nil client.call("")
  end

  # Confirms network failures remain distinguishable from verified zero hires.
  # Returns: assertion results. Errors: assertion failure if transport errors disappear.
  def test_activity_transport_errors_propagate
    assert defined?(UpworkApis::JobActivity), "JobActivity implementation is missing"
    transport = Object.new
    # Parameters: params - unused request. Returns: never. Errors: simulated IOError.
    transport.define_singleton_method(:execute) { |_params| raise IOError, "connection failed" }
    client = UpworkApis::JobActivity.new
    client.graphql = transport
    assert_raises(IOError) { client.call("914") }
  end
end

# Substitutes queue registration; the worker method itself is loaded unchanged.
module Sidekiq
  # Registers the minimal class API required by the worker's declaration.
  module Job
    # Attaches the queue options substitute at inclusion time.
    # Parameters: target - worker class including this module.
    # Returns: nil. Errors: none.
    def self.included(target)
      # Parameters: options - queue configuration. Returns: nil. Errors: none.
      target.define_singleton_method(:sidekiq_options) { |**options| nil }
    end
  end
end
$LOADED_FEATURES << "sidekiq-scheduler.rb"
load File.expand_path("../../app/jobs/cron/sync_jobs.rb", __dir__)

# Supplies the database uniqueness error used by the worker's recovery branch.
module ActiveRecord
  # Marks the recoverable race between concurrent insert attempts.
  class RecordNotUnique < StandardError; end
end
# Records dependency calls at external storage and credential boundaries.
Rails = Struct.new(:logger).new(Logger.new(StringIO.new))
RemoteJobsRepository = Minitest::Mock.new
OauthCredential = Minitest::Mock.new
Tag = Minitest::Mock.new
# Records authenticated marketplace client construction.
UpworkApis::MarketplaceJobs = Minitest::Mock.new

# Verifies the real worker enriches payloads and preserves local-to-remote ordering.
class JobHiringWorkerContractTest < Minitest::Test
  # Runs repeated-tag synchronization with controlled external dependencies.
  # Parameters: failure - whether job activity retrieval raises a transport error.
  # Returns: assertion results. Errors: assertion failures for incorrect worker behavior.
  def exercise_sync(failure: false)
    [:RemoteJobsRepository, :OauthCredential, :Tag].each do |name|
      Object.send(:remove_const, name)
      Object.const_set(name, Minitest::Mock.new)
    end
    UpworkApis.send(:remove_const, :MarketplaceJobs)
    UpworkApis.const_set(:MarketplaceJobs, Minitest::Mock.new)
    repository = Minitest::Mock.new
    repository.expect(:ensure_schema!, true)
    repository.expect(:close, true)
    credential = Minitest::Mock.new
    2.times { credential.expect(:fetch_or_refresh_access_token, "test-token") }
    tags = [Struct.new(:name).new("Ruby"), Struct.new(:name).new("Rails")]
    payload = {"id" => "marketplace-914", "job" => {"id" => "914"},
               "client" => {"totalHires" => 516}, "totalApplicants" => 155}
    marketplace = Minitest::Mock.new
    tags.each { |tag| marketplace.expect(:call, [{"node" => payload.dup}], [tag.name]) }
    calls = []
    activity = Object.new
    # Parameters: job_id - posting identifier. Returns: independent activity counts. Errors: simulated transport failure.
    activity.define_singleton_method(:call) do |job_id|
      calls << job_id
      raise IOError, "fake transport failure" if failure
      {hires: 0, interviews: 3}
    end
    job = Job.new
    job_tags = []
    # Returns: local record identifier. Errors: none.
    job.define_singleton_method(:id) { 914 }
    # Returns: associated tags. Errors: none.
    job.define_singleton_method(:tags) { job_tags }
    # Parameters: attributes - synchronized payload. Returns: normalization result. Errors: callback failures propagate.
    job.define_singleton_method(:update!) do |attributes|
      self.data = attributes.fetch(:data)
      send(:prefill_columns)
    end
    2.times do
      repository.expect(:upsert!, true) do |record|
        assert_same job, record
        assert_equal(failure ? "Unknown" : "No", record.hiring_status)
        assert_equal 155, record.total_applicants
        if failure
          assert_nil record.job_hires_count
          assert_nil record.job_interviews_count
        else
          assert_equal 0, record.job_hires_count
          assert_equal 3, record.job_interviews_count
        end
        true
      end
    end
    RemoteJobsRepository.expect(:from_env, repository)
    OauthCredential.expect(:first, credential)
    Tag.expect(:active, tags)
    2.times { UpworkApis::MarketplaceJobs.expect(:new, marketplace, ["test-token"]) }
    # Parameters: attributes - lookup keys. Returns: local model. Errors: none.
    Job.define_singleton_method(:find_or_create_by) { |attributes| job }
    UpworkApis::JobActivity.stub(:new, ->(*) { activity }) do
      capture_io { Cron::SyncJobs.new.perform }
    end
    assert_equal ["914"], calls, "Repeated tags must share a single job activity request"
    assert_equal tags, job.tags
    [repository, credential, marketplace, RemoteJobsRepository, OauthCredential,
     Tag, UpworkApis::MarketplaceJobs].each(&:verify)
  end

  # Confirms repeated tags fetch activity once and mirror corrected job-specific status.
  # Returns: assertion results. Errors: assertion failures for duplicate requests or stale flags.
  def test_sync_uses_job_id_and_deduplicates_activity
    exercise_sync
  end

  # Confirms an unavailable provider leaves status unknown while synchronization continues.
  # Returns: assertion results. Errors: assertion failures for swallowed jobs or fabricated zero.
  def test_sync_recovers_from_activity_transport_error
    exercise_sync(failure: true)
  end
end

# Reports actual executed production lines after all Minitest tests finish.
Minitest.after_run do
  below_threshold = []
  Coverage.result.each do |path, lines|
    next unless path.end_with?("/app/models/job.rb", "/lib/upwork_apis/job_activity.rb", "/app/jobs/cron/sync_jobs.rb")
    # Model scope includes modified activity counters, hiring methods, and ransacker SQL.
    # Legacy budget and association methods are deliberately excluded from this change's coverage.
    if path.end_with?("/app/models/job.rb")
      source = File.readlines(path)
      selected = []
      scoped_indices = []
      inside = false
      source.each_with_index do |line, index|
        inside = true if line.match?(/^  (?:def (?:self\.ransackable_attributes|activity_count|job_interviews_count|total_applicants|job_hires_count|hired\??|hiring_status|prefill_columns)(?:\(|$)|ransacker :job_hiring_status)/)
        if inside
          selected << lines[index]
          scoped_indices << index
        end
        inside = false if inside && line.match?(/^  end$/)
      end
      executable = selected.compact
    else
      scoped_indices = lines.each_index.to_a
      executable = lines.compact
    end
    covered = executable.count { |hits| hits > 0 }
    below_threshold << path if covered.to_f / executable.length < 0.90
    scope = path.end_with?("/app/models/job.rb") ? "changed job activity declarations" : "whole file"
    puts "COVERAGE #{path} [#{scope}]: #{covered}/#{executable.length} executable lines (#{(100.0 * covered / executable.length).round(2)}%)"
    puts "UNCOVERED #{path}: #{scoped_indices.select { |index| lines[index] == 0 }.map { |index| index + 1 }.join(',')}"
  end
  abort "Hiring coverage below 90%: #{below_threshold.join(", ")}" unless below_threshold.empty?
end

end
