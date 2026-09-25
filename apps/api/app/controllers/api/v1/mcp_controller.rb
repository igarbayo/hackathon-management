# POST /api/v1/mcp (RF-MCP-001). Streamable HTTP: one JSON response per JSON-RPC
# request. Bearer hb_mt_/hb_pat_/hb_it_/hb_oat_. It does not inherit from
# Api::V1::BaseController: it does not require CSRF, like the other Bearer-only
# endpoints (RNF-SEC-003).
module Api
  module V1
    class McpController < ApplicationController
      RESOURCE_METADATA_URL = "%<api_url>s/.well-known/oauth-protected-resource/api/v1/mcp".freeze

      before_action :authenticate_mcp_token!
      before_action :enforce_mcp_rate_limit!

      def create
        result = Mcp::Dispatch.call(
          team: @team, membership: @membership, resolved_token: @resolved_token,
          message: params_hash, session_id: request.headers["Mcp-Session-Id"]
        )

        if result.is_a?(Mcp::Notification)
          head :accepted
        else
          headers["Mcp-Session-Id"] = result.dig("result", "_meta", "sessionId") if result.dig("result", "_meta", "sessionId")
          render json: result
        end
      end

      private

      def params_hash
        request.request_parameters
      end

      def authenticate_mcp_token!
        header = request.headers["Authorization"]
        token = header&.start_with?("Bearer ") ? header.delete_prefix("Bearer ") : nil

        if token.blank?
          return unauthenticated!("missing token")
        end

        @resolved_token = Tokens::Resolve.call(token, expected_resource: "#{ENV.fetch('API_URL', '')}/api/v1/mcp")
        return unauthenticated!("invalid or revoked token") unless @resolved_token

        @team = @resolved_token.team
        @membership = @resolved_token.membership
      end

      def unauthenticated!(message)
        response.headers["WWW-Authenticate"] = %(Bearer resource_metadata="#{format(RESOURCE_METADATA_URL, api_url: ENV.fetch('API_URL', ''))}", scope="read")
        render json: { error: { code: "unauthenticated", message: message } }, status: :unauthorized
      end

      # RNF-API-001: same limit as the rest of the API with a token. It lets
      # ApplicationController#render_rate_limited (rescue_from) return the 429.
      def enforce_mcp_rate_limit!
        return unless @resolved_token

        key = @resolved_token.token_record&.id || "member:#{@resolved_token.membership.id}"
        RateLimiter.check!("token:#{key}", limit: 120, period: 1.minute)
      end
    end
  end
end
