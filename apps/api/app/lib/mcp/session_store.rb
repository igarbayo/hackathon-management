# Stores the clientInfo.name from `initialize` (cut to 40 characters,
# 12-acceso-programatico.md#servidor-mcp) under an Mcp-Session-Id so it can be
# used as via.client in the tools/call calls of that same session. Informational
# and untrusted data: it is never used to authorize anything.
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
