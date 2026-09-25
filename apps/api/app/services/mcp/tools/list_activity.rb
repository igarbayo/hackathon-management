module Mcp
  module Tools
    class ListActivity
      MAX_LIMIT = 50

      def self.tool_name = "list_activity"
      def self.description = "Events from the team's activity feed, as the web app shows them (same privacy rules)."
      def self.scope = nil
      def self.read_only? = true

      def self.input_schema
        {
          "type" => "object",
          "properties" => {
            "since" => { "type" => "string", "format" => "date-time" },
            "feature_key" => { "type" => "string" },
            "member" => { "type" => "string" },
            "source" => { "type" => "string", "enum" => ActivityEvent::SOURCES },
            "limit" => { "type" => "integer", "minimum" => 1, "maximum" => MAX_LIMIT }
          },
          "additionalProperties" => false
        }
      end

      def self.call(team:, membership:, resolved_token:, args:)
        scope = ActivityEvent.where(team_id: team.id)
        scope = scope.where(:occurred_at.gte => Time.iso8601(args["since"])) if args["since"].present?
        scope = scope.where(source: args["source"]) if args["source"].present?

        if args["feature_key"].present?
          feature = Mcp::FindFeature.call(team: team, key: args["feature_key"])
          scope = scope.where("attribution.feature_id" => feature.id)
        end

        if args["member"].present?
          member = Mcp::ResolveMember.call(team: team, value: args["member"], current_membership: membership)
          scope = scope.where("actor.user_id" => member.user_id.to_s)
        end

        limit = [ args["limit"].to_i, 1 ].max
        limit = MAX_LIMIT if args["limit"].blank? || limit > MAX_LIMIT

        events = scope.order(occurred_at: :desc).limit(limit)
        { events: events.map { |e| ActivityEventSerializer.new(e).as_json } }
      end
    end
  end
end
