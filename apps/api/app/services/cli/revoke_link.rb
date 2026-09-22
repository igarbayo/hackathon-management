# Usado por DELETE /cli/me (Bearer) y DELETE /teams/:id/me/claude_code
# (sesión): mismo contrato, dos vías de autenticación (RF-CC-010).
module Cli
  class RevokeLink
    def self.call(membership:, purge:)
      link = membership.claude_code
      raise ApiError::NotFound.new(message: "Claude Code no está conectado") unless link

      if purge
        # RF-SEC-002: "desconectar y borrar mis eventos" incluye tanto los de
        # Claude Code como los del MCP (spec 12), no solo los del CLI.
        ActivityEvent.where(team_id: membership.team_id, "actor.membership_id" => membership.id.to_s)
                     .any_in(source: %w[claude_code mcp])
                     .delete_all
      end

      membership.claude_code = nil
      membership.save!
    end
  end
end
