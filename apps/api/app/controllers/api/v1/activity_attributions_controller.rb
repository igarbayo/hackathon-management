# RF-ATR-004/005. Ojo: el cuerpo trae un campo llamado "action", que en
# Rails choca con params[:action] (el nombre de la acción del controlador,
# que gana siempre en el merge). Por eso se lee del cuerpo crudo con
# request.request_parameters en vez de con params[:action].
module Api
  module V1
    class ActivityAttributionsController < Api::V1::BaseController
      include TeamScoping
      include FeatureLookup

      requires_scope "attribution:write", only: %i[create bulk]

      BULK_LIMIT = 100

      def create
        event = find_event(params[:event_id])
        feature = find_feature_param(params[:feature_id])

        result = ::Attribution::Decide.call(event: event, action: decision_action, decided_by: current_user, feature: feature)

        render json: ActivityEventSerializer.new(result).as_json
      rescue ::Attribution::Decide::InvalidAction => e
        raise ApiError::BadRequest.new(message: e.message)
      end

      def bulk
        event_ids = Array(bulk_params["event_ids"])
        raise ApiError::BadRequest.new(message: "máximo #{BULK_LIMIT} eventos") if event_ids.size > BULK_LIMIT

        action = bulk_params["action"]
        feature = find_feature_param(bulk_params["feature_id"])

        updated = event_ids.filter_map do |event_id|
          event = ActivityEvent.where(team_id: current_team.id, id: event_id).first
          next unless event

          ::Attribution::Decide.call(event: event, action: action, decided_by: current_user, feature: feature)
        rescue ::Attribution::Decide::InvalidAction
          nil
        end

        render json: { data: updated.map { |e| ActivityEventSerializer.new(e).as_json } }
      end

      private

      def decision_action
        request.request_parameters["action"]
      end

      def bulk_params
        request.request_parameters
      end

      def find_event(id)
        ActivityEvent.where(team_id: current_team.id, id: id).first.tap do |event|
          raise ApiError::NotFound.new(message: "evento no encontrado") unless event
        end
      end

      def find_feature_param(feature_id)
        return nil if feature_id.blank?

        Feature.where(team_id: current_team.id, id: feature_id).first.tap do |feature|
          raise ApiError::NotFound.new(message: "feature no encontrada") unless feature
        end
      end
    end
  end
end
