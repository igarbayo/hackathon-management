# /teams/:team_id/oauth_connections (RF-API-021). "An owner sees the whole
# team's and can revoke them": unlike /me/oauth_connections (the personal view),
# this lists all the team's OAuth connections, from any member, and only an
# owner uses it.
module Api
  module V1
    module Teams
      class OAuthConnectionsController < Api::V1::BaseController
        include TeamScoping

        session_only :index, :destroy

        def index
          require_owner!
          connections = AccessToken.where(kind: "oauth", team_id: current_team.id, revoked_at: nil)
                                    .group_by(&:refresh_family_id)

          render json: { data: connections.map { |family_id, tokens| connection_json(family_id, tokens) } }
        end

        def destroy
          require_owner!
          tokens = AccessToken.where(kind: "oauth", team_id: current_team.id, refresh_family_id: params[:id], revoked_at: nil)
          raise ApiError::NotFound.new(message: "connection not found") unless tokens.exists?

          tokens.each { |token| token.update!(revoked_at: Time.current, revoke_reason: "manual") }
          head :no_content
        end

        private

        def connection_json(family_id, tokens)
          latest = tokens.max_by(&:created_at)
          earliest = tokens.min_by(&:created_at)
          client = latest.oauth_client
          membership = Membership.where(team_id: current_team.id, user_id: latest.user_id).first

          {
            id: family_id,
            client: { id: client&.id&.to_s, name: client&.name, first_party: client&.first_party? },
            user: { id: latest.user_id.to_s, display_name: membership&.display_name },
            scopes: latest.scopes,
            last_used_at: latest.last_used_at&.iso8601,
            created_at: earliest.created_at.iso8601
          }
        end
      end
    end
  end
end
