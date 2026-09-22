# RF-DL-003: milestones + features con deadline, cada una con overdue: bool.
module Api
  module V1
    class TimelineController < Api::V1::BaseController
      include TeamScoping

      requires_scope "read", only: :show

      def show
        now = Time.current

        milestones = Milestone.where(team_id: current_team.id).map do |m|
          { type: "milestone", id: m.id.to_s, title: m.title, kind: m.kind, due_at: m.due_at.iso8601, overdue: m.due_at < now }
        end

        features = Feature.where(team_id: current_team.id, :deadline.ne => nil).map do |f|
          { type: "feature", id: f.id.to_s, key: f.key, title: f.title, due_at: f.deadline.iso8601, overdue: f.deadline < now && f.status != "done" }
        end

        render json: { data: (milestones + features).sort_by { |item| item[:due_at] } }
      end
    end
  end
end
