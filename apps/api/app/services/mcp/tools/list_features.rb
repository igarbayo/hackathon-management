module Mcp
  module Tools
    class ListFeatures
      def self.tool_name = "list_features"
      def self.description = "Lists the team's features, optionally filtered by status, objective, text or only those assigned to the caller."
      def self.scope = nil
      def self.read_only? = true

      def self.input_schema
        {
          "type" => "object",
          "properties" => {
            "status" => { "type" => "string", "enum" => Feature::STATUSES },
            "mine" => { "type" => "boolean" },
            "objective_key" => { "type" => "string" },
            "q" => { "type" => "string" }
          },
          "additionalProperties" => false
        }
      end

      def self.call(team:, membership:, resolved_token:, args:)
        scope = Feature.where(team_id: team.id)
        scope = scope.where(status: args["status"]) if args["status"].present?
        scope = scope.where(title: /#{Regexp.escape(args['q'])}/i) if args["q"].present?

        if args["objective_key"].present?
          objective = Mcp::FindObjective.call(team: team, key: args["objective_key"])
          scope = scope.where(objective_ids: objective.id)
        end

        if args["mine"]
          raise Mcp::ToolError, "\"mine\" is not available for an integration token." unless membership

          scope = scope.where(assignee_ids: membership.id)
        end

        features = scope.order(status: :asc, position: :asc).limit(50)
        { features: features.map { |f| summary(f) } }
      end

      def self.summary(feature)
        {
          key: feature.key, title: feature.title, status: feature.status, assignees: feature.assignee_ids.map(&:to_s),
          deadline: feature.deadline&.iso8601, score: feature.score, last_activity_at: feature.status_changed_at&.iso8601
        }
      end
      private_class_method :summary
    end
  end
end
