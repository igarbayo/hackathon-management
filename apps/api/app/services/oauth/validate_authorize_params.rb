# GET /oauth/authorize (RF-API-012). Antes de tener un redirect_uri
# validado no se redirige nunca el error (evita usarlo como open redirect);
# después sí, con ?error=…&state=… como pide OAuth 2.1.
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
      raise DirectError, "falta client_id" if params[:client_id].blank?

      client = OAuthClient.where(client_id: params[:client_id]).first
      raise DirectError, "client_id desconocido" unless client

      raise DirectError, "redirect_uri no está registrado para este cliente" unless client.redirect_uris.include?(params[:redirect_uri])

      raise RedirectError, "unsupported_response_type" unless params[:response_type] == "code"
      raise RedirectError, "invalid_request" if params[:code_challenge].blank? || params[:code_challenge_method] != "S256"

      resource = params[:resource]
      raise RedirectError, "invalid_target" unless RESOURCES.call(ENV.fetch("API_URL", "")).include?(resource)

      Result.new(client: client, redirect_uri: params[:redirect_uri])
    end
  end
end
