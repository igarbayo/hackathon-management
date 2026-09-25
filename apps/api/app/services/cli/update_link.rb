# Used by PATCH /cli/me (Bearer) and PATCH /teams/:id/me/claude_code (session):
# same contract, two ways to authenticate (RF-CC-010).
module Cli
  class UpdateLink
    def self.call(membership:, privacy_level: nil, paused: nil)
      link = membership.claude_code
      raise ApiError::NotFound.new(message: "Claude Code is not connected") unless link

      attrs = {}
      if privacy_level
        raise ApiError::BadRequest.new(message: "invalid privacy level") unless ClaudeCodeLink::PRIVACY_LEVELS.include?(privacy_level)

        attrs[:privacy_level] = privacy_level
      end
      attrs[:paused] = paused unless paused.nil?

      link.update!(attrs)
      membership
    end
  end
end
