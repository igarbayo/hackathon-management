# RNF-GH-002: cupo de la API de GitHub de cada instalación, compartido entre
# todos los jobs. Client apunta aquí lo último que dijo GitHub
# (x-ratelimit-*) y, si ya se ha bajado del 20 % de reserva, deja de llamar
# hasta el reset sin gastar otra petición en descubrirlo.
module Github
  module RateBudget
    RESERVE = 0.2

    def self.record(installation_id, limit:, remaining:, reset_at:)
      ttl = (reset_at - Time.current).ceil
      return unless ttl.positive?

      value = { "limit" => limit, "remaining" => remaining, "reset_at" => reset_at.to_i }.to_json
      Sidekiq.redis { |conn| conn.call("SET", key(installation_id), value, "EX", ttl.to_s) }
    end

    # Hasta cuándo no se puede llamar, o nil si queda cupo por encima de la reserva.
    def self.exhausted_until(installation_id)
      raw = Sidekiq.redis { |conn| conn.call("GET", key(installation_id)) }
      return nil unless raw

      budget = JSON.parse(raw)
      reset_at = Time.at(budget["reset_at"])
      return nil if reset_at <= Time.current

      below_reserve?(budget["remaining"], budget["limit"]) ? reset_at : nil
    end

    def self.below_reserve?(remaining, limit)
      limit.to_i.positive? && remaining.to_i < limit.to_i * RESERVE
    end

    def self.key(installation_id)
      "github:rate_budget:#{installation_id}"
    end
  end
end
