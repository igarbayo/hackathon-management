# POST /oauth/register, RFC 7591. Todos los clientes registrados así son
# públicos, sin secreto (RNF-SEC-015); los first_party los crea el equipo
# de Hackboard a mano, no por este endpoint.
module OAuth
  class RegisterClient
    LOOPBACK_PATTERN = %r{\Ahttp://(127\.0\.0\.1|localhost)(:\d+)?(/|\z)}

    class InvalidRedirectUri < StandardError; end

    def self.call(redirect_uris:, client_name:, client_uri: nil, logo_uri: nil)
      uris = Array(redirect_uris)
      raise InvalidRedirectUri, "hace falta al menos un redirect_uri" if uris.empty?
      uris.each { |uri| validate_uri!(uri) }

      OAuthClient.create!(
        client_id: SecureRandom.uuid,
        registration: "dynamic",
        name: client_name.presence || "Cliente sin nombre",
        redirect_uris: uris,
        client_uri: client_uri,
        logo_uri: logo_uri
      )
    end

    def self.validate_uri!(uri)
      return if uri.start_with?("https://") || uri.match?(LOOPBACK_PATTERN)

      raise InvalidRedirectUri, "#{uri} tiene que ser HTTPS, o http://127.0.0.1/localhost para apps nativas"
    end
    private_class_method :validate_uri!
  end
end
