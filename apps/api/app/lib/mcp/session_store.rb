# Guarda el clientInfo.name del `initialize` (recortado a 40 caracteres,
# 12-acceso-programatico.md#servidor-mcp) bajo un Mcp-Session-Id para poder
# usarlo como via.client en las llamadas a tools/call de esa misma sesión.
# Dato informativo y no confiable: nunca se usa para autorizar nada.
module Mcp
  module SessionStore
    TTL = 4.hours
    MAX_CLIENT_NAME_LENGTH = 40

    def self.create(client_name)
      session_id = SecureRandom.uuid
      Sidekiq.redis { |c| c.call("SET", key(session_id), client_name.to_s[0, MAX_CLIENT_NAME_LENGTH], "EX", TTL.to_i) }
      session_id
    end

    def self.client_name(session_id)
      return nil if session_id.blank?

      Sidekiq.redis { |c| c.call("GET", key(session_id)) }
    end

    def self.key(session_id)
      "mcp_session:#{session_id}"
    end
  end
end
