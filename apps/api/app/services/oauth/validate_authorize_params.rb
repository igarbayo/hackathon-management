# GET /oauth/authorize (RF-API-012). Before there is a validated redirect_uri,
# the error is never redirected (so it cannot be used as an open redirect);
# after that it is, with ?error=…&state=… as OAuth 2.1 asks.
module OAuth
  class ValidateAuthorizeParams
    RESOURCES = ->(api_url) { [ "#{api_url}/api/v1", "#{api_url}/api/v1/mcp" ] }

    Result = Struct.new(:client, :redirect_uri, keyword_init: true)

    class DirectError < StandardError
      def initialize(message)
        super(message)
      end
    end

    class RedirectError < StandardError
      attr_reader :code

      def initialize(code)
        @code = code
        super(code)
      end
    end

    def self.call(params)
      raise DirectError, "missing client_id" if params[:client_id].blank?

      client = OAuthClient.where(client_id: params[:client_id]).first
      raise DirectError, "unknown client_id" unless client

      raise DirectError, "redirect_uri is not registered for this client" unless client.redirect_uris.include?(params[:redirect_uri])

      raise RedirectError, "unsupported_response_type" unless params[:response_type] == "code"
      raise RedirectError, "invalid_request" if params[:code_challenge].blank? || params[:code_challenge_method] != "S256"

      resource = params[:resource]
      raise RedirectError, "invalid_target" unless RESOURCES.call(ENV.fetch("API_URL", "")).include?(resource)

      Result.new(client: client, redirect_uri: params[:redirect_uri])
    end
  end
end
