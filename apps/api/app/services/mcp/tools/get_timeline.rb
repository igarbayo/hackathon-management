module Mcp
  module Tools
    class GetTimeline
      def self.tool_name = "get_timeline"
      def self.description = "Milestones and features with a deadline, marking which ones are overdue."
      def self.scope = nil
      def self.read_only? = true

      def self.input_schema
        { "type" => "object", "properties" => {}, "additionalProperties" => false }
      end

      def self.call(team:, membership:, resolved_token:, args:)
        now = Time.current

        milestones = Milestone.where(team_id: team.id).map do |m|
          { type: "milestone", id: m.id.to_s, title: m.title, kind: m.kind, due_at: m.due_at.iso8601, overdue: m.due_at < now }
        end

        features = Feature.where(team_id: team.id, :deadline.ne => nil).map do |f|
          { type: "feature", key: f.key, title: f.title, due_at: f.deadline.iso8601, overdue: f.deadline < now && f.status != "done" }
        end

        { items: (milestones + features).sort_by { |item| item[:due_at] } }
      end
    end
  end
end
