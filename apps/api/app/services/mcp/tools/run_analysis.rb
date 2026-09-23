module Mcp
  module Tools
    class RunAnalysis
      def self.tool_name = "run_analysis"
      def self.description = "Encola un análisis de cobertura manual. Respeta la cuota diaria del plan del equipo."
      def self.scope = "analyses:run"
      def self.read_only? = false

      def self.input_schema
        { "type" => "object", "properties" => {}, "additionalProperties" => false }
      end

      def self.call(team:, membership:, resolved_token:, args:)
        Analysis::Quota.check_manual!(team)
        # Sin membership (token de integración: actúa como la integración,
        # no como una persona), RunJob cae a la clave del owner del equipo,
        # igual que un análisis programado.
        if membership && membership.user.gemini_api_key.blank?
          raise Mcp::ToolError, "Configura tu clave de Gemini en tu perfil (Ajustes) para poder analizar."
        end

        analysis = Analysis::Enqueue.call(team: team, trigger: "manual", requested_by: membership&.user)

        { id: analysis.id.to_s, status: analysis.status }
      rescue Analysis::Quota::ExceededError => e
        raise Mcp::ToolError, "#{e.message}. Vuelve a intentarlo más tarde."
      end
    end
  end
end
