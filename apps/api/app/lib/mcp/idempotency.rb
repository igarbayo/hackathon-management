# idempotency_key for create_feature
# (12-acceso-programatico.md#herramientas-de-escritura--rf-mcp-003-f5-aceptado). Same mechanism as RF-API-005 but
# per (token, tool, key), since a single POST /api/v1/mcp serves many different tools.
module Mcp
  module Idempotency
    TTL = 24.hours

    def self.fetch(resolved_token, tool_name, key)
      return nil if key.blank?

      raw = Sidekiq.redis { |c| c.call("GET", redis_key(resolved_token, tool_name, key)) }
      raw && JSON.parse(raw, symbolize_names: true)
    end

    def self.store(resolved_token, tool_name, key, result)
      return if key.blank?

      Sidekiq.redis { |c| c.call("SET", redis_key(resolved_token, tool_name, key), result.to_json, "EX", TTL.to_i) }
    end

    def self.redis_key(resolved_token, tool_name, key)
      identity = resolved_token.token_record&.id || resolved_token.membership&.id
      "mcp_idem:#{identity}:#{tool_name}:#{key}"
    end
  end
end
