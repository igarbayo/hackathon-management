# Usado por PATCH /cli/me (Bearer) y PATCH /teams/:id/me/claude_code
# (sesión): mismo contrato, dos vías de autenticación (RF-CC-010).
module Cli
  class UpdateLink
    def self.call(membership:, privacy_level: nil, paused: nil)
      link = membership.claude_code
      raise ApiError::NotFound.new(message: "Claude Code no está conectado") unless link

      attrs = {}
      if privacy_level
        raise ApiError::BadRequest.new(message: "nivel de privacidad no válido") unless ClaudeCodeLink::PRIVACY_LEVELS.include?(privacy_level)

        attrs[:privacy_level] = privacy_level
      end
      attrs[:paused] = paused unless paused.nil?

      link.update!(attrs)
      membership
    end
  end
end
