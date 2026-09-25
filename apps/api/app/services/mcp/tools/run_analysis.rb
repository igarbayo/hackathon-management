module Mcp
  module Tools
    class RunAnalysis
      def self.tool_name = "run_analysis"
      def self.description = "Queues a manual coverage analysis. It respects the daily quota of the team's plan."
      def self.scope = "analyses:run"
      def self.read_only? = false

      def self.input_schema
        { "type" => "object", "properties" => {}, "additionalProperties" => false }
      end

      def self.call(team:, membership:, resolved_token:, args:)
        Analysis::Quota.check_manual!(team)
        # With no membership (integration token: it acts as the integration, not
        # as a person), RunJob falls back to the team owner's key, like a
        # scheduled analysis.
        if membership && membership.user.gemini_api_key.blank?
          raise Mcp::ToolError, "Set up your Gemini key in your profile (Settings) to run an analysis."
        end

        analysis = Analysis::Enqueue.call(team: team, trigger: "manual", requested_by: membership&.user)

        { id: analysis.id.to_s, status: analysis.status }
      rescue Analysis::Quota::ExceededError => e
        raise Mcp::ToolError, "#{e.message}. Try again later."
      end
    end
  end
end
