# POST /oauth/register (RFC 7591). Public, no session or CSRF.
module OAuth
  class RegistrationsController < ApplicationController
    before_action :enforce_rate_limit!

    def create
      client = ::OAuth::RegisterClient.call(
        redirect_uris: params[:redirect_uris], client_name: params[:client_name],
        client_uri: params[:client_uri], logo_uri: params[:logo_uri]
      )

      render json: {
        client_id: client.client_id, client_name: client.name, redirect_uris: client.redirect_uris,
        token_endpoint_auth_method: "none", grant_types: %w[authorization_code refresh_token], response_types: [ "code" ]
      }, status: :created
    rescue ::OAuth::RegisterClient::InvalidRedirectUri => e
      render json: { error: "invalid_redirect_uri", error_description: e.message }, status: :bad_request
    end

    private

    # RF-API-012: /oauth/register, 10 registrations per hour per IP.
    def enforce_rate_limit!
      RateLimiter.check!("oauth_register:#{request.remote_ip}", limit: 10, period: 1.hour)
    end
  end
end
