# POST /oauth/token (RF-API-012). No session, no CSRF: they are public clients
# with no secret (RNF-SEC-015) that authenticate with PKCE, not with a cookie.
module OAuth
  class TokensController < ApplicationController
    before_action :enforce_rate_limit!

    def create
      case params[:grant_type]
      when "authorization_code" then authorization_code
      when "refresh_token" then refresh_token
      else
        render json: { error: "unsupported_grant_type" }, status: :bad_request
      end
    end

    private

    def authorization_code
      result = ::OAuth::ExchangeCode.call(
        code: params[:code], redirect_uri: params[:redirect_uri], client_id: params[:client_id], code_verifier: params[:code_verifier]
      )
      render json: token_response(result)
    rescue ::OAuth::ExchangeCode::InvalidGrant => e
      render json: { error: "invalid_grant", error_description: e.message }, status: :bad_request
    end

    def refresh_token
      result = ::OAuth::RefreshToken.call(refresh_token: params[:refresh_token], client_id: params[:client_id])
      render json: token_response(result)
    rescue ::OAuth::RefreshToken::ReuseDetected => e
      render json: { error: "invalid_grant", error_description: e.message }, status: :bad_request
    end

    def token_response(result)
      {
        access_token: result[:access_token], refresh_token: result[:refresh_token],
        token_type: "Bearer", expires_in: result[:expires_in], scope: result[:scopes].join(" ")
      }
    end

    # RF-API-012: /oauth/token, 30 requests per minute per client.
    def enforce_rate_limit!
      return if params[:client_id].blank?

      RateLimiter.check!("oauth_token:#{params[:client_id]}", limit: 30, period: 1.minute)
    end
  end
end
