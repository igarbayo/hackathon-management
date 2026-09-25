# El `state` firmado que llevan /auth/github y /auth/google (RF-AUTH-004,
# RF-AUTH-008). Solo protege el flujo de login, no tiene relación con el
# servidor de autorización OAuth 2.1 de specs/12.
module OAuthLoginState
  TTL = 10.minutes

  module_function

  def verifier
    Rails.application.message_verifier(:oauth_login_state)
  end

  # `link_user_id` y `return_to` solo los usa "Vincular GitHub" desde una
  # sesión abierta (RF-TEAM-014): el callback añade la identidad a esa cuenta
  # en vez de iniciar sesión.
  def generate(nonce: nil, link_user_id: nil, return_to: nil)
    claims = { nonce: nonce, issued_at: Time.current.to_i, link_user_id: link_user_id, return_to: return_to }.compact
    verifier.generate(claims, expires_in: TTL)
  end

  def verify(state)
    verifier.verify(state)
  rescue ActiveSupport::MessageVerifier::InvalidSignature
    raise ApiError::BadRequest.new(message: "state inválido o caducado")
  end
end
