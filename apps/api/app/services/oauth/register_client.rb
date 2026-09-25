# POST /oauth/register, RFC 7591. All clients registered this way are public,
# with no secret (RNF-SEC-015); first_party ones are created by the Hackboard
# team by hand, not through this endpoint.
module OAuth
  class RegisterClient
    LOOPBACK_PATTERN = %r{\Ahttp://(127\.0\.0\.1|localhost)(:\d+)?(/|\z)}

    class InvalidRedirectUri < StandardError; end

    def self.call(redirect_uris:, client_name:, client_uri: nil, logo_uri: nil)
      uris = Array(redirect_uris)
      raise InvalidRedirectUri, "at least one redirect_uri is required" if uris.empty?
      uris.each { |uri| validate_uri!(uri) }

      OAuthClient.create!(
        client_id: SecureRandom.uuid,
        registration: "dynamic",
        name: client_name.presence || "Unnamed client",
        redirect_uris: uris,
        client_uri: client_uri,
        logo_uri: logo_uri
      )
    end

    def self.validate_uri!(uri)
      return if uri.start_with?("https://") || uri.match?(LOOPBACK_PATTERN)

      raise InvalidRedirectUri, "#{uri} must be HTTPS, or http://127.0.0.1/localhost for native apps"
    end
    private_class_method :validate_uri!
  end
end
