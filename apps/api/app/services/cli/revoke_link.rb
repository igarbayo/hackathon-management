# Used by DELETE /cli/me (Bearer) and DELETE /teams/:id/me/claude_code
# (session): same contract, two ways to authenticate (RF-CC-010).
module Cli
  class RevokeLink
    def self.call(membership:, purge:)
      link = membership.claude_code
      raise ApiError::NotFound.new(message: "Claude Code is not connected") unless link

      if purge
        # RF-SEC-002: "disconnect and delete my events" covers both Claude Code
        # and MCP events (spec 12), not only the CLI's.
        ActivityEvent.where(team_id: membership.team_id, "actor.membership_id" => membership.id.to_s)
                     .any_in(source: %w[claude_code mcp])
                     .delete_all
      end

      membership.claude_code = nil
      membership.save!
    end
  end
end
