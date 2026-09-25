# /teams/:team_id/tokens (RF-API-001). Web session only: a PAT cannot create or
# manage other tokens. Any member creates PATs for themselves; an owner sees and
# revokes other people's, but does not create them or see their value (nobody
# sees it twice, RNF-SEC-002).
module Api
  module V1
    class TokensController < Api::V1::BaseController
      include TeamScoping

      session_only :index, :create, :destroy

      def index
        scope = AccessToken.where(team_id: current_team.id, kind: "pat")
        scope = scope.where(membership_id: current_membership.id) unless current_membership.owner?

        render json: { data: scope.order(created_at: :desc).map { |t| AccessTokenSerializer.new(t).as_json } }
      end

      def create
        result = ::Pat::Create.call(
          membership: current_membership,
          name: params[:name],
          preset: params[:preset],
          scopes: params[:scopes],
          expires_at: params[:expires_at].presence && Time.iso8601(params[:expires_at])
        )

        render json: AccessTokenSerializer.new(result.record).as_json.merge(token: result.raw_token), status: :created
      end

      def destroy
        token = AccessToken.where(team_id: current_team.id, kind: "pat", id: params[:id], revoked_at: nil).first
        raise ApiError::NotFound.new(message: "token not found") unless token

        unless token.membership_id == current_membership.id || current_membership.owner?
          raise ApiError::Forbidden.new(message: "only the token owner or an owner can revoke it")
        end

        token.update!(revoked_at: Time.current, revoked_by_id: current_user.id, revoke_reason: "manual")
        head :no_content
      end
    end
  end
end
