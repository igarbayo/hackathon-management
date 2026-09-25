# Fixed-window counter in Redis. It does not try to be exact at the limit (a
# fixed window allows bursts at the edge), but it is enough to stop brute force
# and enumeration (03-api.md, RNF-API-001).
module RateLimiter
  class LimitExceeded < StandardError
    attr_reader :retry_after

    def initialize(retry_after)
      @retry_after = retry_after
      super("rate limited")
    end
  end

  module_function

  def check!(key, limit:, period:)
    full_key = "rate_limit:#{key}"

    count = Sidekiq.redis { |conn| conn.call("INCR", full_key) }
    Sidekiq.redis { |conn| conn.call("EXPIRE", full_key, period.to_i) } if count == 1

    return if count <= limit

    ttl = Sidekiq.redis { |conn| conn.call("TTL", full_key) }
    raise LimitExceeded, (ttl.positive? ? ttl : period.to_i)
  end
end
