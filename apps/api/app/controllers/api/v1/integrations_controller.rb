# /teams/:team_id/integrations (RF-API-011). Owners only, session only: they
# create, revoke and rotate them. The actor is the integration, not a person.
module Api
  module V1
    class IntegrationsController < Api::V1::BaseController
      include TeamScoping

      session_only :index, :create, :destroy, :rotate

      def index
        require_owner!
        tokens = AccessToken.where(team_id: current_team.id, kind: "integration").order(created_at: :desc)
        render json: { data: tokens.map { |t| AccessTokenSerializer.new(t).as_json } }
      end

      def create
        require_owner!
        result = ::Integration::Create.call(team: current_team, created_by: current_user, name: params[:name], scopes: params[:scopes])

        render json: AccessTokenSerializer.new(result.record).as_json.merge(token: result.raw_token), status: :created
      end

      def destroy
        require_owner!
        token = find_integration
        token.update!(revoked_at: Time.current, revoked_by_id: current_user.id, revoke_reason: "manual")
        head :no_content
      end

      def rotate
        require_owner!
        result = ::Integration::Rotate.call(token: find_integration)
        render json: AccessTokenSerializer.new(result.record).as_json.merge(token: result.raw_token)
      end

      private

      def find_integration
        token = AccessToken.where(team_id: current_team.id, kind: "integration", id: params[:id], revoked_at: nil).first
        raise ApiError::NotFound.new(message: "integration not found") unless token

        token
      end
    end
  end
end
