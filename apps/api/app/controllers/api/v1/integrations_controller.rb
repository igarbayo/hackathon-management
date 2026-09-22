# /teams/:team_id/integrations (RF-API-011). Solo owners, solo sesión: los
# crean, revocan y rotan. El actor es la integración, no una persona.
module Api
  module V1
    class IntegrationsController < Api::V1::BaseController
      include TeamScoping

      session_only :index, :create, :destroy

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
        token = AccessToken.where(team_id: current_team.id, kind: "integration", id: params[:id], revoked_at: nil).first
        raise ApiError::NotFound.new(message: "integración no encontrada") unless token

        token.update!(revoked_at: Time.current, revoked_by_id: current_user.id, revoke_reason: "manual")
        head :no_content
      end
    end
  end
end
