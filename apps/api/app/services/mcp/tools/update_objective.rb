module Mcp
  module Tools
    class UpdateObjective
      def self.tool_name = "update_objective"
      def self.description = "Edita un objetivo (no lo borra)."
      def self.scope = "objectives:write"
      def self.read_only? = false

      def self.input_schema
        {
          "type" => "object",
          "required" => [ "key" ],
          "properties" => {
            "key" => { "type" => "string" },
            "title" => { "type" => "string" },
            "description" => { "type" => "string" },
            "priority" => { "type" => "string", "enum" => Objective::PRIORITIES }
          },
          "additionalProperties" => false
        }
      end

      def self.call(team:, membership:, resolved_token:, args:)
        objective = Mcp::FindObjective.call(team: team, key: args["key"])
        attrs = args.slice("title", "description", "priority").compact
        objective.update!(attrs)

        Tracking::RecordApiChange.call(team: team, membership: membership, resolved_token: resolved_token, entity: "objective", key: objective.key, fields: attrs.keys, channel: "mcp")
        ::Webhooks::Enqueue.call(team: team, event: "objective.updated", data: ObjectiveSerializer.new(objective).as_json)

        ObjectiveSerializer.new(objective).as_json
      end
    end
  end
end
