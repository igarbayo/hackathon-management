# /me/oauth_connections (RF-API-021). "Apps conectadas": ve y revoca sus
# propias conexiones OAuth, sin importar en qué equipo se autorizaron.
# Excepción de RNF-SEC-001 igual que Membership en MeController#destroy: es
# una vista centrada en la persona, no en un equipo.
module Api
  module V1
    class OAuthConnectionsController < Api::V1::BaseController
      before_action :authenticate_user!

      def index
        connections = AccessToken.where(kind: "oauth", user_id: current_user.id, revoked_at: nil)
                                  .group_by(&:refresh_family_id)

        render json: { data: connections.map { |family_id, tokens| connection_json(family_id, tokens) } }
      end

      def destroy
        tokens = AccessToken.where(kind: "oauth", user_id: current_user.id, refresh_family_id: params[:id], revoked_at: nil)
        raise ApiError::NotFound.new(message: "conexión no encontrada") unless tokens.exists?

        tokens.each { |token| token.update!(revoked_at: Time.current, revoke_reason: "manual") }
        head :no_content
      end

      private

      def connection_json(family_id, tokens)
        latest = tokens.max_by(&:created_at)
        earliest = tokens.min_by(&:created_at)
        client = latest.oauth_client

        {
          id: family_id,
          client: { id: client&.id&.to_s, name: client&.name, first_party: client&.first_party? },
          team_id: latest.team_id.to_s,
          scopes: latest.scopes,
          last_used_at: latest.last_used_at&.iso8601,
          created_at: earliest.created_at.iso8601
        }
      end
    end
  end
end
