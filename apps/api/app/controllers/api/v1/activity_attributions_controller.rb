# RF-ATR-004/005. Careful: the body has a field called "action", which in Rails
# clashes with params[:action] (the controller action name, which always wins in
# the merge). That is why it is read from the raw body with
# request.request_parameters instead of params[:action].
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
        raise ApiError::BadRequest.new(message: "at most #{BULK_LIMIT} events") if event_ids.size > BULK_LIMIT

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
          raise ApiError::NotFound.new(message: "event not found") unless event
        end
      end

      def find_feature_param(feature_id)
        return nil if feature_id.blank?

        Feature.where(team_id: current_team.id, id: feature_id).first.tap do |feature|
          raise ApiError::NotFound.new(message: "feature not found") unless feature
        end
      end
    end
  end
end
