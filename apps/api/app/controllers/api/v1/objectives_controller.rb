module Api
  module V1
    class ObjectivesController < Api::V1::BaseController
      include TeamScoping

      session_only :destroy
      requires_scope "read", only: :index
      requires_scope "objectives:write", only: %i[create update]

      def index
        objectives = Objective.where(team_id: current_team.id).order(position: :asc, number: :asc)
        render json: { data: objectives.map { |o| ObjectiveSerializer.new(o).as_json } }
      end

      def create
        objective = Objective.new(objective_params)
        objective.team = current_team
        objective.created_by_id = current_user&.id
        objective.save!
        record_api_change!(entity: "objective", key: objective.key, fields: objective_params.keys)
        ::Webhooks::Enqueue.call(team: current_team, event: "objective.created", data: ObjectiveSerializer.new(objective).as_json)

        render json: ObjectiveSerializer.new(objective).as_json, status: :created
      end

      def update
        objective = find_objective
        attrs = params.permit(:title, :description, :priority, :position).to_h
        attrs["archived_at"] = archived_at_from_param if params.key?(:archived)

        objective.update!(attrs)
        record_api_change!(entity: "objective", key: objective.key, fields: attrs.keys)
        ::Webhooks::Enqueue.call(team: current_team, event: "objective.updated", data: ObjectiveSerializer.new(objective).as_json)

        render json: ObjectiveSerializer.new(objective).as_json
      end

      def destroy
        objective = find_objective
        Feature.where(team_id: current_team.id, objective_ids: objective.id).each do |feature|
          feature.pull(objective_ids: objective.id)
        end
        objective.destroy!

        head :no_content
      end

      private

      def find_objective
        Objective.where(team_id: current_team.id, id: params[:id]).first.tap do |objective|
          raise ApiError::NotFound.new(message: "objetivo no encontrado") unless objective
        end
      end

      def archived_at_from_param
        ActiveModel::Type::Boolean.new.cast(params[:archived]) ? Time.current : nil
      end

      def objective_params
        params.permit(:title, :description, :priority)
      end
    end
  end
end
