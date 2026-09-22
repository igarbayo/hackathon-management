module Mcp
  module Tools
    class ListObjectives
      def self.tool_name = "list_objectives"
      def self.description = "Lista los objetivos del equipo con su cobertura de features."
      def self.scope = nil
      def self.read_only? = true

      def self.input_schema
        { "type" => "object", "properties" => {}, "additionalProperties" => false }
      end

      def self.call(team:, membership:, resolved_token:, args:)
        coverage_by_key = latest_coverage_by_key(team)

        objectives = Objective.where(team_id: team.id).order(position: :asc, number: :asc).map do |objective|
          ObjectiveSerializer.new(objective).as_json.merge(coverage: coverage_by_key[objective.key])
        end

        { objectives: objectives }
      end

      def self.latest_coverage_by_key(team)
        analysis = AiAnalysis.where(team_id: team.id, status: "succeeded").order(created_at: :desc).first
        return {} unless analysis

        (analysis.result["coverage"] || []).index_by { |row| row["objective_key"] }.transform_values { |row| row["status"] }
      end
      private_class_method :latest_coverage_by_key
    end
  end
end
