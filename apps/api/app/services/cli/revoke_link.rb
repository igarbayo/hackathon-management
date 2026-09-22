# Usado por DELETE /cli/me (Bearer) y DELETE /teams/:id/me/claude_code
# (sesión): mismo contrato, dos vías de autenticación (RF-CC-010).
module Cli
  class RevokeLink
    def self.call(membership:, purge:)
      link = membership.claude_code
      raise ApiError::NotFound.new(message: "Claude Code no está conectado") unless link

      if purge
        ActivityEvent.where(team_id: membership.team_id, source: "claude_code", "actor.membership_id" => membership.id.to_s).delete_all
      end

      membership.claude_code = nil
      membership.save!
    end
  end
end
