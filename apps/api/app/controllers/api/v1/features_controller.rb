module Api
  module V1
    class FeaturesController < Api::V1::BaseController
      include TeamScoping
      include OptimisticConcurrency
      include FeatureLookup

      session_only :destroy
      requires_scope "read", only: %i[index show]
      requires_scope "features:write", only: %i[create update move]

      def index
        scope = Feature.where(team_id: current_team.id)
        scope = scope.where(status: params[:status]) if params[:status].present?
        scope = scope.where(assignee_ids: params[:assignee_id]) if params[:assignee_id].present?
        scope = scope.where(objective_ids: params[:objective_id]) if params[:objective_id].present?
        scope = scope.where(title: /#{Regexp.escape(params[:q])}/i) if params[:q].present?

        features = scope.order(status: :asc, position: :asc)
        render json: { data: features.map { |f| FeatureSerializer.new(f).as_json } }
      end

      def show
        render json: FeatureSerializer.new(find_feature, detail: true, viewer_id: current_user&.id).as_json
      end

      def create
        # feature_created already records the change, with via if a token made it.
        feature = ::Features::Create.call(
          team: current_team, created_by: current_user, attrs: feature_params, actor: current_actor, via: current_via
        )

        render json: FeatureSerializer.new(feature, detail: true, viewer_id: current_user&.id).as_json, status: :created
      end

      def update
        feature = find_feature
        check_if_match!(feature, ->(f) { FeatureSerializer.new(f, detail: true) })

        attrs = params.permit(:title, :description, :status, :deadline, objective_ids: [], assignee_ids: []).to_h
        ::Features::Update.call(feature: feature, attrs: attrs, via: current_via, actor: current_actor)
        record_api_change!(entity: "feature", key: feature.key, fields: attrs.keys - %w[status assignee_ids])

        render json: FeatureSerializer.new(feature, detail: true, viewer_id: current_user&.id).as_json
      end

      def move
        feature = find_feature
        check_if_match!(feature, ->(f) { FeatureSerializer.new(f, detail: true) })

        ::Features::Move.call(feature: feature, status: params[:status], before_id: params[:before_id], after_id: params[:after_id], via: current_via, actor: current_actor)

        render json: FeatureSerializer.new(feature, detail: true, viewer_id: current_user&.id).as_json
      end

      def destroy
        feature = find_feature

        if ActivityEvent.where(team_id: current_team.id, "attribution.feature_id" => feature.id).exists?
          raise ApiError::Conflict.new(message: "it has attributed events, drop it (status: discarded) instead of deleting it")
        end

        feature.destroy!
        head :no_content
      end

      private

      def find_feature
        find_feature_by_key_or_id(params[:key])
      end

      def feature_params
        params.permit(:title, :description, :status, :deadline, objective_ids: [], assignee_ids: [])
      end
    end
  end
end
