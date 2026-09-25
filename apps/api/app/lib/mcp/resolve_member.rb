# "me", an id or an exact display_name -> Membership (assign_feature, list_activity). Used only by MCP tools,
# which are more lenient about the format than the REST API
# (12-acceso-programatico.md#herramientas-de-escritura--rf-mcp-003-f5-aceptado).
module Mcp
  module ResolveMember
    def self.call(team:, value:, current_membership:)
      return nil if value.blank?

      if value == "me"
        raise Mcp::ToolError, "\"me\" is not valid for an integration token" unless current_membership

        return current_membership
      end

      by_id = value.to_s.match?(/\A[0-9a-f]{24}\z/i) ? Membership.where(team_id: team.id, id: value).first : nil

      by_id || Membership.where(team_id: team.id, display_name: value).first ||
        raise(Mcp::ToolError, "Could not find \"#{value}\" in the team.")
    end
  end
end
