module Api
  module V1
    class MilestonesController < Api::V1::BaseController
      include TeamScoping

      session_only :destroy
      requires_scope "read", only: :index
      requires_scope "milestones:write", only: %i[create update]

      def index
        milestones = Milestone.where(team_id: current_team.id).order(due_at: :asc)
        render json: { data: milestones.map { |m| MilestoneSerializer.new(m).as_json } }
      end

      def create
        milestone = Milestone.new(milestone_params)
        milestone.team = current_team
        milestone.save!
        record_api_change!(entity: "milestone", key: milestone.id.to_s, fields: milestone_params.keys)
        ::Webhooks::Enqueue.call(team: current_team, event: "milestone.created", data: MilestoneSerializer.new(milestone).as_json)

        render json: MilestoneSerializer.new(milestone).as_json, status: :created
      end

      def update
        milestone = find_milestone
        milestone.update!(milestone_params)
        record_api_change!(entity: "milestone", key: milestone.id.to_s, fields: milestone_params.keys)
        ::Webhooks::Enqueue.call(team: current_team, event: "milestone.updated", data: MilestoneSerializer.new(milestone).as_json)

        render json: MilestoneSerializer.new(milestone).as_json
      end

      def destroy
        find_milestone.destroy!
        head :no_content
      end

      private

      def find_milestone
        Milestone.where(team_id: current_team.id, id: params[:id]).first.tap do |milestone|
          raise ApiError::NotFound.new(message: "milestone not found") unless milestone
        end
      end

      def milestone_params
        params.permit(:title, :kind, :due_at, :description)
      end
    end
  end
end
