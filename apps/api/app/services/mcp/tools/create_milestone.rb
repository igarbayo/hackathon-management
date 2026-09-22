module Mcp
  module Tools
    class CreateMilestone
      def self.tool_name = "create_milestone"
      def self.description = "Crea un milestone."
      def self.scope = "milestones:write"
      def self.read_only? = false

      def self.input_schema
        {
          "type" => "object",
          "required" => %w[title kind due_at],
          "properties" => {
            "title" => { "type" => "string" },
            "kind" => { "type" => "string", "enum" => Milestone::KINDS },
            "due_at" => { "type" => "string", "format" => "date-time" },
            "description" => { "type" => "string" }
          },
          "additionalProperties" => false
        }
      end

      def self.call(team:, membership:, resolved_token:, args:)
        milestone = Milestone.new(title: args["title"], kind: args["kind"], due_at: args["due_at"], description: args["description"])
        milestone.team = team
        milestone.save!

        fields = %w[title kind due_at description].select { |f| args[f].present? }
        Tracking::RecordApiChange.call(team: team, membership: membership, resolved_token: resolved_token, entity: "milestone", key: milestone.id.to_s, fields: fields, channel: "mcp")
        ::Webhooks::Enqueue.call(team: team, event: "milestone.created", data: MilestoneSerializer.new(milestone).as_json)

        MilestoneSerializer.new(milestone).as_json
      end
    end
  end
end
