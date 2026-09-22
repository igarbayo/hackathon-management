module Mcp
  module Tools
    class GetFeature
      def self.tool_name = "get_feature"
      def self.description = "Detalle de una feature: descripción, objetivos, asignados, pros y contras con votos, ramas vinculadas y sus últimos eventos atribuidos."
      def self.scope = nil
      def self.read_only? = true

      def self.input_schema
        { "type" => "object", "required" => [ "key" ], "properties" => { "key" => { "type" => "string" } }, "additionalProperties" => false }
      end

      def self.call(team:, membership:, resolved_token:, args:)
        feature = Mcp::FindFeature.call(team: team, key: args["key"])
        events = ActivityEvent.where(team_id: team.id, "attribution.feature_id" => feature.id).order(occurred_at: :desc).limit(10)

        FeatureSerializer.new(feature, detail: true).as_json.merge(recent_events: events.map { |e| ActivityEventSerializer.new(e).as_json })
      end
    end
  end
end
