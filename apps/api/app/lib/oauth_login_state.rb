# The signed `state` that /auth/github and /auth/google carry (RF-AUTH-004,
# RF-AUTH-008). It only protects the login flow; it has nothing to do with the
# OAuth 2.1 authorization server from specs/12.
module OAuthLoginState
  TTL = 10.minutes

  module_function

  def verifier
    Rails.application.message_verifier(:oauth_login_state)
  end

  # `link_user_id` and `return_to` are only used by "Link GitHub" from a
  # signed-in session (RF-TEAM-014): the callback adds the identity to that
  # account instead of signing in.
  def generate(nonce: nil, link_user_id: nil, return_to: nil)
    claims = { nonce: nonce, issued_at: Time.current.to_i, link_user_id: link_user_id, return_to: return_to }.compact
    verifier.generate(claims, expires_in: TTL)
  end

  def verify(state)
    verifier.verify(state)
  rescue ActiveSupport::MessageVerifier::InvalidSignature
    raise ApiError::BadRequest.new(message: "invalid or expired state")
  end
end
