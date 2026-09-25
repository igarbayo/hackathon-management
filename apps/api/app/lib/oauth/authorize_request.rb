# Pending authorization request between GET /oauth/authorize and POST
# /oauth/authorize/decision, signed instead of stored on the server (same
# pattern as Github::InstallState/OAuthLoginState: no server session between the
# redirect to the web app and the decision).
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
      raise ApiError::BadRequest.new(message: "invalid or expired request_id")
    end
  end
end
