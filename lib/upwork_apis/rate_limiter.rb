module UpworkApis
  # Applies Upwork API call governance across all workers and request paths.
  #
  # Parameters:
  # - none
  #
  # Returns:
  # - UpworkApis::RateLimiter instance for block-based execution helpers.
  #
  # Errors:
  # - RateLimitError: raised when rate-limiting continues after retries are exhausted.
  class RateLimiter
    # Raised after retries have been exhausted while throttled by Upwork.
    class RateLimitError < StandardError; end

    # Response state when the request can proceed.
    ALLOWED = 2

    # Response state when the per-second bucket is full.
    SECOND_WINDOW_FULL = 0

    # Response state when the per-minute bucket is full.
    MINUTE_WINDOW_FULL = 1

    LUA_SCRIPT = <<~LUA
      local second_key = KEYS[1]
      local minute_key = KEYS[2]
      local second_limit = tonumber(ARGV[1])
      local minute_limit = tonumber(ARGV[2])

      local second_count = redis.call("INCR", second_key)
      if second_count == 1 then
        redis.call("PEXPIRE", second_key, 1000)
      end

      if second_count > second_limit then
        redis.call("DECR", second_key)
        return {0, redis.call("PTTL", second_key)}
      end

      local minute_count = redis.call("INCR", minute_key)
      if minute_count == 1 then
        redis.call("PEXPIRE", minute_key, 60000)
      end

      if minute_count > minute_limit then
        redis.call("DECR", minute_key)
        return {1, redis.call("PTTL", minute_key)}
      end

      return {2, 0}
    LUA

    # Run a block under limiter and retry policy.
    #
    # Parameters:
    # - +block+: [Proc] the API call to execute.
    #
    # Returns:
    # - The value returned by +block+ when it succeeds.
    #
    # Throws:
    # - RateLimitError: when Upwork keeps responding with 429 for all retries.
    # - Any other exceptions from +block+ are re-raised to caller.
    def self.execute
      new.execute { yield }
    end

    # @return [RateLimiter]
    #   Constructed limiter with configuration loaded from environment.
    def initialize
      @per_second_limit = ENV.fetch("UPWORK_RATE_LIMIT_PER_SECOND", "8").to_i
      @per_minute_limit = ENV.fetch("UPWORK_RATE_LIMIT_PER_MINUTE", "240").to_i
      @max_retries = ENV.fetch("UPWORK_API_RETRY_MAX", "5").to_i
      @base_delay = ENV.fetch("UPWORK_API_RETRY_BASE_SECONDS", "0.75").to_f
      @max_delay = ENV.fetch("UPWORK_API_RETRY_MAX_SECONDS", "30").to_f
    end

    # Execute one Upwork API request through the limiter.
    #
    # Parameters:
    # - +&block+: [Proc] request body to run once a slot is available.
    #
    # Returns:
    # - [Object] the response returned by the request block.
    #
    # Throws:
    # - RateLimitError: throttled after all retries are used.
    # - Any exception raised by +block+ if it is not classified as a rate-limit signal.
    def execute
      attempts = 0
      loop do
        wait_for_slot

        response = yield
        if rate_limited_response?(response)
          attempts += 1
          raise RateLimitError, "Upwork API rate limit reached" if attempts > @max_retries

          sleep(retry_delay(attempts, rate_limit_retry_after(response)))
          next
        end

        return response
      end
    end

    private

    # Wait until a token is available in both second and minute buckets.
    #
    # Returns:
    # - None. This method blocks until available.
    #
    # Raises:
    # - Any Sidekiq/Redis exceptions from the Redis command path.
    def wait_for_slot
      loop do
        state, ttl_ms = acquire_window_slot
        break if state == ALLOWED

        delay = ttl_ms.to_f / 1000.0
        sleep([delay, 0.05].max)
      end
    end

    # Consume one limiter token from both configured windows.
    #
    # Returns:
    # - [Integer, Integer] state code and TTL in milliseconds for blocking sleep.
    def acquire_window_slot
      now = Time.now.to_i
      second_key = "upwork:api:ratelimit:sec:#{now}"
      minute_key = "upwork:api:ratelimit:min:#{now / 60}"

      Sidekiq.redis do |conn|
        conn.call(
          :eval,
          LUA_SCRIPT,
          2,
          second_key,
          minute_key,
          @per_second_limit,
          @per_minute_limit
        )
      end
    end

    # Resolve the Redis connection from Sidekiq.
    #
    # Returns:
    # - Redis::Client currently configured by Sidekiq.
    def redis_client
      Sidekiq.redis { |conn| conn }
    end

    # Detects Upwork limit violation in payload or response metadata.
    #
    # Parameters:
    # - response: [Hash, HTTParty::Response, Object]
    #
    # Returns:
    # - [Boolean] true when request is known to be rate-limited.
    def rate_limited_response?(response)
      return true if response_is_hash_rate_error?(response)
      return true if response.respond_to?(:code) && response.code.to_i == 429
      false
    end

    # Parse rate-limit details from response body when available.
    #
    # Parameters:
    # - response: [Object]
    #
    # Returns:
    # - [Float,nil] seconds to wait before next retry, if supplied.
    def rate_limit_retry_after(response)
      if response.respond_to?(:headers)
        retry_after = response.headers["retry-after"] || response.headers["Retry-After"]
        return retry_after.to_f if retry_after.present?
      end

      if response.is_a?(Hash)
        extension = response.dig("errors", 0, "extensions") || {}
        retry_after = extension["retry_after"]
        return retry_after.to_f if retry_after.present?
      end

      nil
    end

    # Build a jittered exponential delay for retry attempts.
    #
    # Parameters:
    # - attempt: [Integer] current attempt counter (starts at 1).
    # - retry_after: [Numeric,nil] server-provided delay override.
    #
    # Returns:
    # - [Float] seconds to wait before retry.
    def retry_delay(attempt, retry_after)
      return [retry_after, 0.0].max if retry_after.present? && retry_after.positive?

      backoff = (@base_delay * (2**(attempt - 1)))
      jitter = rand * 0.2
      [backoff + jitter, @max_delay].min
    end

    # Safely interpret GraphQL error payloads.
    #
    # Parameters:
    # - response: [Hash]
    #
    # Returns:
    # - [Boolean] true when GraphQL payload reports too many requests.
    def response_is_hash_rate_error?(response)
      return false unless response.is_a?(Hash)

      errors = response["errors"]
      return false unless errors.is_a?(Array)

      errors.any? do |error|
        error_hash = error.respond_to?(:to_h) ? error.to_h : {}
        message = error_hash.fetch("message", "").to_s.downcase
        status = error_hash.fetch("status", "").to_s
        extensions = error_hash.fetch("extensions", {})
        rate_code = extensions.to_h.fetch("code", "").to_s
        rate_status = extensions.to_h.fetch("status", "").to_s

        message.include?("too many requests") ||
          status == "429" ||
          status == "rate_limit_exceeded" ||
          rate_code == "TOO_MANY_REQUESTS" ||
          rate_code == "rate_limit" ||
          rate_status == "429" ||
          rate_status == "TOO_MANY_REQUESTS"
      end
    end
  end
end
