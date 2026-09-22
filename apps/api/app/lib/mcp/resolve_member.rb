# "me", un id o un display_name exacto -> Membership (assign_feature,
# list_activity). Usado solo por herramientas MCP, que son más permisivas
# con el formato que la API REST (12-acceso-programatico.md#herramientas-de-escritura--rf-mcp-003-f5-aceptado).
module Mcp
  module ResolveMember
    def self.call(team:, value:, current_membership:)
      return nil if value.blank?

      if value == "me"
        raise Mcp::ToolError, "\"me\" no es válido para un token de integración" unless current_membership

        return current_membership
      end

      by_id = value.to_s.match?(/\A[0-9a-f]{24}\z/i) ? Membership.where(team_id: team.id, id: value).first : nil

      by_id || Membership.where(team_id: team.id, display_name: value).first ||
        raise(Mcp::ToolError, "No se ha encontrado a \"#{value}\" en el equipo.")
    end
  end
end
