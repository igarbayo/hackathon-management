module Mcp
  module Tools
    class Whoami
      def self.tool_name = "whoami"
      def self.description = "Equipo, miembro, tipo de token, scopes y caducidad del token con el que se llama. Útil para saber qué se puede hacer antes de intentarlo."
      def self.scope = nil
      def self.read_only? = true

      def self.input_schema
        { "type" => "object", "properties" => {}, "additionalProperties" => false }
      end

      def self.call(team:, membership:, resolved_token:, args:)
        {
          kind: resolved_token.kind,
          token_prefix: resolved_token.token_prefix,
          team: { id: team.id.to_s, name: team.name },
          member: membership && { id: membership.id.to_s, display_name: membership.display_name, role: membership.role },
          scopes: resolved_token.scopes,
          expires_at: resolved_token.token_record&.expires_at&.iso8601
        }
      end
    end
  end
end
