# Petición de autorización pendiente entre GET /oauth/authorize y
# POST /oauth/authorize/decision, firmada en vez de guardada en el servidor
# (mismo patrón que Github::InstallState/OAuthLoginState: sin sesión de
# servidor entre el redirect a la web y la decisión).
module OAuth
  module AuthorizeRequest
    TTL = 10.minutes

    def self.verifier
      Rails.application.message_verifier(:oauth_authorize_request)
    end

    def self.generate(params)
      verifier.generate(params, expires_in: TTL)
    end

    def self.verify(request_id)
      verifier.verify(request_id)
    rescue ActiveSupport::MessageVerifier::InvalidSignature
      raise ApiError::BadRequest.new(message: "request_id inválido o caducado")
    end
  end
end
