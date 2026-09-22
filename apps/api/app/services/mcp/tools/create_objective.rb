module Mcp
  module Tools
    class CreateObjective
      def self.tool_name = "create_objective"
      def self.description = "Crea un objetivo."
      def self.scope = "objectives:write"
      def self.read_only? = false

      def self.input_schema
        {
          "type" => "object",
          "required" => %w[title priority],
          "properties" => {
            "title" => { "type" => "string" },
            "description" => { "type" => "string" },
            "priority" => { "type" => "string", "enum" => Objective::PRIORITIES }
          },
          "additionalProperties" => false
        }
      end

      def self.call(team:, membership:, resolved_token:, args:)
        objective = Objective.new(title: args["title"], description: args["description"], priority: args["priority"])
        objective.team = team
        objective.created_by_id = membership&.user_id
        objective.save!

        fields = %w[title description priority].select { |f| args[f].present? }
        Tracking::RecordApiChange.call(team: team, membership: membership, resolved_token: resolved_token, entity: "objective", key: objective.key, fields: fields, channel: "mcp")
        ::Webhooks::Enqueue.call(team: team, event: "objective.created", data: ObjectiveSerializer.new(objective).as_json)
        ObjectiveSerializer.new(objective).as_json
      end
    end
  end
end
