# The signed `state` that /auth/github and /auth/google carry (RF-AUTH-004,
# RF-AUTH-008). It only protects the login flow; it has nothing to do with the
# OAuth 2.1 authorization server from specs/12.
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
    raise ApiError::BadRequest.new(message: "invalid or expired state")
  end
end
