# El `state` firmado que llevan /auth/github y /auth/google (RF-AUTH-004,
# RF-AUTH-008). Solo protege el flujo de login, no tiene relación con el
# servidor de autorización OAuth 2.1 de specs/12.
module OAuthLoginState
  TTL = 10.minutes

  module_function

  def verifier
    Rails.application.message_verifier(:oauth_login_state)
  end

  def generate(nonce: nil)
    verifier.generate({ nonce: nonce, issued_at: Time.current.to_i }, expires_in: TTL)
  end

  def verify(state)
    verifier.verify(state)
  rescue ActiveSupport::MessageVerifier::InvalidSignature
    raise ApiError::BadRequest.new(message: "state inválido o caducado")
  end
end
