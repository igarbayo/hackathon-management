# Contador de ventana fija en Redis. No pretende ser exacto al límite (una
# ventana fija permite ráfagas en el borde), pero es suficiente para frenar
# fuerza bruta y enumeración (03-api.md, RNF-API-001).
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
