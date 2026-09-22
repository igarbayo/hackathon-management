module Api
  module V1
    class MilestonesController < Api::V1::BaseController
      include TeamScoping

      session_only :destroy
      requires_scope "read", only: :index
      requires_scope "milestones:write", only: %i[create update]

      def index
        milestones = Milestone.where(team_id: current_team.id).order(due_at: :asc)
        render json: { data: milestones.map { |m| milestone_json(m) } }
      end

      def create
        milestone = Milestone.new(milestone_params)
        milestone.team = current_team
        milestone.save!

        render json: milestone_json(milestone), status: :created
      end

      def update
        milestone = find_milestone
        milestone.update!(milestone_params)
        render json: milestone_json(milestone)
      end

      def destroy
        find_milestone.destroy!
        head :no_content
      end

      private

      def find_milestone
        Milestone.where(team_id: current_team.id, id: params[:id]).first.tap do |milestone|
          raise ApiError::NotFound.new(message: "milestone no encontrado") unless milestone
        end
      end

      def milestone_params
        params.permit(:title, :kind, :due_at, :description)
      end

      def milestone_json(milestone)
        {
          id: milestone.id.to_s,
          title: milestone.title,
          kind: milestone.kind,
          due_at: milestone.due_at&.iso8601,
          description: milestone.description
        }
      end
    end
  end
end
