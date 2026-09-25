module Mcp
  module Tools
    class GetLatestAnalysis
      def self.tool_name = "get_latest_analysis"
      def self.description = "Summary of the latest completed coverage analysis, with the coverage matrix and the deterministic alerts."
      def self.scope = nil
      def self.read_only? = true

      def self.input_schema
        { "type" => "object", "properties" => {}, "additionalProperties" => false }
      end

      def self.call(team:, membership:, resolved_token:, args:)
        analysis = AiAnalysis.where(team_id: team.id, status: "succeeded").order(created_at: :desc).first
        {
          analysis: analysis && AiAnalysisSerializer.new(analysis).as_json,
          deterministic_alerts: Analysis::DeterministicAlerts.call(team)
        }
      end
    end
  end
end
