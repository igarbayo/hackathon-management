# GET /api/v1/token (RF-API-…, "Introspection" section of 12). With any Bearer:
# so an agent knows what it can do before trying it.
module Api
  module V1
    class TokenIntrospectionController < ApplicationController
      def show
        header = request.headers["Authorization"]
        raise ApiError::Unauthenticated.new(message: "missing token") unless header&.start_with?("Bearer ")

        resolved = ::Tokens::Resolve.call(header.delete_prefix("Bearer "))
        raise ApiError::Unauthenticated.new(message: "invalid or revoked token") unless resolved

        render json: {
          kind: resolved.kind,
          token_prefix: resolved.token_prefix,
          team: { id: resolved.team.id.to_s, name: resolved.team.name },
          member: { id: resolved.membership.id.to_s, display_name: resolved.membership.display_name, role: resolved.membership.role },
          scopes: resolved.scopes,
          expires_at: resolved.token_record&.expires_at&.iso8601
        }
      end
    end
  end
end
