# Public metadata, no auth (RFC 8414, RFC 9728). MCP clients use it to find out
# how to authenticate (12-acceso-programatico.md#oauth-21).
module OAuth
  class DiscoveryController < ApplicationController
    def authorization_server
      render json: {
        issuer: api_url,
        authorization_endpoint: "#{api_url}/oauth/authorize",
        token_endpoint: "#{api_url}/oauth/token",
        registration_endpoint: "#{api_url}/oauth/register",
        revocation_endpoint: "#{api_url}/oauth/revoke",
        scopes_supported: ::OAuth::SCOPES,
        response_types_supported: [ "code" ],
        grant_types_supported: %w[authorization_code refresh_token],
        code_challenge_methods_supported: [ "S256" ],
        token_endpoint_auth_methods_supported: [ "none" ]
      }
    end

    def protected_resource_mcp
      render json: protected_resource("#{api_url}/api/v1/mcp")
    end

    def protected_resource_api
      render json: protected_resource("#{api_url}/api/v1")
    end

    private

    def protected_resource(resource)
      { resource: resource, authorization_servers: [ api_url ], scopes_supported: ::OAuth::SCOPES }
    end

    def api_url
      ENV.fetch("API_URL", "")
    end
  end
end
