# Creates the single-use, 60s code (OAuthGrant::DEFAULT_TTL) that POST
# /oauth/token exchanges with PKCE (12-acceso-programatico.md#oauth-21).
module OAuth
  class AuthorizeCode
    def self.call(client:, user:, membership:, scopes:, redirect_uri:, resource:, code_challenge:)
      raw_code = SecureRandom.hex(32)

      OAuthGrant.create!(
        team_id: membership.team_id,
        code_digest: Digest::SHA256.hexdigest(raw_code),
        oauth_client: client,
        user: user,
        membership: membership,
        scopes: scopes,
        redirect_uri: redirect_uri,
        resource: resource,
        code_challenge: code_challenge,
        expires_at: OAuthGrant::DEFAULT_TTL.from_now
      )

      raw_code
    end
  end
end
