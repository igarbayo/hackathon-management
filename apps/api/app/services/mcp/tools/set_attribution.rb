module Mcp
  module Tools
    class SetAttribution
      def self.tool_name = "set_attribution"
      def self.description = "Confirms, rejects or sets by hand the attribution of a feed event to a feature."
      def self.scope = "attribution:write"
      def self.read_only? = false

      def self.input_schema
        {
          "type" => "object",
          "required" => %w[event_id action],
          "properties" => {
            "event_id" => { "type" => "string" },
            "action" => { "type" => "string", "enum" => Attribution::Decide::ACTIONS },
            "feature_key" => { "type" => "string" }
          },
          "additionalProperties" => false
        }
      end

      def self.call(team:, membership:, resolved_token:, args:)
        event = ActivityEvent.where(team_id: team.id, id: args["event_id"]).first
        raise Mcp::ToolError, "Event not found. Use list_activity to see the ids." unless event

        feature = args["feature_key"].present? ? Mcp::FindFeature.call(team: team, key: args["feature_key"]) : nil

        result = ::Attribution::Decide.call(event: event, action: args["action"], decided_by: membership&.user, feature: feature)
        ActivityEventSerializer.new(result).as_json
      rescue ::Attribution::Decide::InvalidAction => e
        raise Mcp::ToolError, e.message
      end
    end
  end
end
