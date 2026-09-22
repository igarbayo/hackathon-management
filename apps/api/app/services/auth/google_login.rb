module Auth
  class GoogleLogin
    AuthorizationFailed = Class.new(StandardError)

    AUTHORIZE_URL = "https://accounts.google.com/o/oauth2/v2/auth"
    TOKEN_URL = "https://oauth2.googleapis.com/token"
    JWKS_URL = "https://www.googleapis.com/oauth2/v3/certs"
    ISSUERS = %w[accounts.google.com https://accounts.google.com].freeze

    def self.authorize_url(state:)
      params = {
        client_id: ENV.fetch("GOOGLE_CLIENT_ID", ""),
        redirect_uri: callback_url,
        response_type: "code",
        scope: "openid email profile",
        state: state,
        nonce: nonce_for(state),
        code_challenge: pkce_challenge(state),
        code_challenge_method: "S256"
      }
      "#{AUTHORIZE_URL}?#{params.to_query}"
    end

    def self.callback_url
      "#{ENV.fetch('API_URL', '')}/api/v1/auth/google/callback"
    end

    # El nonce y el code_verifier de PKCE se derivan del propio `state`
    # firmado: no hace falta guardar nada en el servidor entre /auth/google
    # y su callback (no hay sesión todavía).
    def self.pkce_challenge(state)
      Base64.urlsafe_encode64(Digest::SHA256.digest(code_verifier(state)), padding: false)
    end

    def self.code_verifier(state)
      derive(state, "pkce")
    end

    def self.nonce_for(state)
      derive(state, "nonce")
    end

    def self.derive(state, label)
      OpenSSL::HMAC.hexdigest("SHA256", Rails.application.secret_key_base, "google-#{label}:#{state}")
    end
    private_class_method :derive

    def self.call(code:, state:)
      id_token = exchange_code(code, state)
      claims = verify_id_token(id_token, nonce_for(state))

      find_or_create_user(claims)
    end

    def self.exchange_code(code, state)
      response = connection.post(TOKEN_URL) do |req|
        req.body = {
          client_id: ENV.fetch("GOOGLE_CLIENT_ID", ""),
          client_secret: ENV.fetch("GOOGLE_CLIENT_SECRET", ""),
          code: code,
          redirect_uri: callback_url,
          grant_type: "authorization_code",
          code_verifier: code_verifier(state)
        }
      end

      id_token = response.body["id_token"]
      raise AuthorizationFailed, "Google no devolvió un id_token" if id_token.blank?

      id_token
    end
    private_class_method :exchange_code

    def self.verify_id_token(id_token, expected_nonce)
      _, header = JWT.decode(id_token, nil, false)
      key = jwk_for(header["kid"])

      payload, = JWT.decode(id_token, key.public_key, true, algorithms: [ "RS256" ])

      unless ISSUERS.include?(payload["iss"])
        raise AuthorizationFailed, "iss inválido"
      end
      unless payload["aud"] == ENV.fetch("GOOGLE_CLIENT_ID", "")
        raise AuthorizationFailed, "aud inválido"
      end
      unless payload["nonce"] == expected_nonce
        raise AuthorizationFailed, "nonce inválido"
      end
      unless payload["email_verified"]
        raise AuthorizationFailed, "el email de Google no está verificado"
      end

      payload
    rescue JWT::DecodeError => e
      raise AuthorizationFailed, "id_token inválido: #{e.message}"
    end
    private_class_method :verify_id_token

    def self.jwk_for(kid)
      set = JWT::JWK::Set.new(jwks_body)
      jwk = set.find { |candidate| candidate[:kid] == kid }
      raise AuthorizationFailed, "no se encontró la clave pública de Google (kid=#{kid})" unless jwk

      JWT::JWK.import(jwk)
    end
    private_class_method :jwk_for

    def self.jwks_body
      connection.get(JWKS_URL).body
    end
    private_class_method :jwks_body

    def self.find_or_create_user(claims)
      google_sub = claims["sub"]
      email = claims["email"]&.downcase

      user = User.where(google_sub: google_sub).first
      user ||= (email.present? ? User.where(email: email).first : nil)

      if user
        user.update!(google_sub: google_sub, avatar_url: user.avatar_url || claims["picture"])
      else
        user = User.create!(
          email: email,
          name: claims["name"].presence || email,
          google_sub: google_sub,
          avatar_url: claims["picture"]
        )
      end

      user
    end
    private_class_method :find_or_create_user

    def self.connection
      Faraday.new do |f|
        f.request :url_encoded
        f.response :json, content_type: /\bjson\b/
        f.adapter Faraday.default_adapter
      end
    end
    private_class_method :connection
  end
end
