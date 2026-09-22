module Mcp
  module Tools
    class UpdateMilestone
      def self.tool_name = "update_milestone"
      def self.description = "Edita un milestone."
      def self.scope = "milestones:write"
      def self.read_only? = false

      def self.input_schema
        {
          "type" => "object",
          "required" => [ "id" ],
          "properties" => {
            "id" => { "type" => "string" },
            "title" => { "type" => "string" },
            "kind" => { "type" => "string", "enum" => Milestone::KINDS },
            "due_at" => { "type" => "string", "format" => "date-time" },
            "description" => { "type" => "string" }
          },
          "additionalProperties" => false
        }
      end

      def self.call(team:, membership:, resolved_token:, args:)
        milestone = Milestone.where(team_id: team.id, id: args["id"]).first
        raise Mcp::ToolError, "Milestone no encontrado. Usa get_timeline para ver los ids." unless milestone

        attrs = args.slice("title", "kind", "due_at", "description").compact
        milestone.update!(attrs)

        Tracking::RecordApiChange.call(team: team, membership: membership, resolved_token: resolved_token, entity: "milestone", key: milestone.id.to_s, fields: attrs.keys, channel: "mcp")
        ::Webhooks::Enqueue.call(team: team, event: "milestone.updated", data: MilestoneSerializer.new(milestone).as_json)

        MilestoneSerializer.new(milestone).as_json
      end
    end
  end
end
