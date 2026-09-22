# Como mucho un análisis en curso por equipo, con lock en Redis con TTL de
# 5 min (06-analisis-ia.md#disparo).
module Analysis
  class Lock
    TTL_SECONDS = 5.minutes.to_i

    def self.acquire(team_id)
      key = "analysis_lock:#{team_id}"
      acquired = Sidekiq.redis { |conn| conn.call("SET", key, "1", "NX", "EX", TTL_SECONDS.to_s) }
      !acquired.nil?
    end

    def self.release(team_id)
      Sidekiq.redis { |conn| conn.call("DEL", "analysis_lock:#{team_id}") }
    end
  end
end
