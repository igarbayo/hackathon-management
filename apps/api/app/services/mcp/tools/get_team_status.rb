module Mcp
  module Tools
    class GetTeamStatus
      def self.tool_name = "get_team_status"
      def self.scope = nil
      def self.read_only? = true

      def self.description
        "Snapshot of the project right now: time until the hackathon ends and until the next milestone, " \
          "features by status, your features in progress, overdue features, coverage from the latest analysis and its " \
          "alerts, and the 10 latest feed events. Call this tool when you start a work session."
      end

      def self.input_schema
        { "type" => "object", "properties" => {}, "additionalProperties" => false }
      end

      def self.call(team:, membership:, resolved_token:, args:)
        {
          hackathon_ends_at: team.hackathon&.ends_at&.iso8601,
          next_milestone: next_milestone,
          features_by_status: Feature.where(team_id: team.id).group_by(&:status).transform_values(&:size),
          my_features_in_progress: my_features_in_progress(team, membership),
          overdue_features: overdue_features(team),
          coverage: coverage(team),
          deterministic_alerts: Analysis::DeterministicAlerts.call(team),
          recent_activity: ActivityEvent.where(team_id: team.id).order(occurred_at: :desc).limit(10).map { |e| ActivityEventSerializer.new(e).as_json }
        }
      end

      def self.next_milestone
        milestone = Milestone.upcoming.first
        milestone && { title: milestone.title, due_at: milestone.due_at.iso8601 }
      end
      private_class_method :next_milestone

      def self.my_features_in_progress(team, membership)
        return [] unless membership

        Feature.where(team_id: team.id, status: "in_progress", assignee_ids: membership.id).map { |f| { key: f.key, title: f.title } }
      end
      private_class_method :my_features_in_progress

      def self.overdue_features(team)
        Feature.where(team_id: team.id, :deadline.lt => Time.current).and(:status.ne => "done").and(:status.ne => "discarded")
               .map { |f| { key: f.key, title: f.title, deadline: f.deadline.iso8601 } }
      end
      private_class_method :overdue_features

      def self.coverage(team)
        analysis = AiAnalysis.where(team_id: team.id, status: "succeeded").order(created_at: :desc).first
        return nil unless analysis

        rows = analysis.result["coverage"] || []
        covered = rows.count { |r| r["status"] == "covered" }
        { percent: rows.empty? ? 0 : ((covered.to_f / rows.size) * 100).round, analyzed_at: analysis.finished_at&.iso8601 }
      end
      private_class_method :coverage
    end
  end
end
