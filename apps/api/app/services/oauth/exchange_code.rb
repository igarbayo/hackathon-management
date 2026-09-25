# POST /oauth/token, grant_type=authorization_code (RF-API-012, RNF-SEC-015):
# PKCE S256 required, exact redirect_uri and client_id, single-use 60s code.
module OAuth
  class ExchangeCode
    class InvalidGrant < StandardError; end

    def self.call(code:, redirect_uri:, client_id:, code_verifier:)
      raise InvalidGrant, "code_verifier obligatorio" if code_verifier.blank?

      grant = OAuthGrant.where(code_digest: Digest::SHA256.hexdigest(code.to_s)).first
      raise InvalidGrant, "invalid code" unless grant
      raise InvalidGrant, "code already used" if grant.used?
      raise InvalidGrant, "code expired" if grant.expired?
      raise InvalidGrant, "redirect_uri does not match" unless grant.redirect_uri == redirect_uri
      raise InvalidGrant, "client_id does not match" unless grant.oauth_client.client_id == client_id
      raise InvalidGrant, "code_verifier does not match" unless pkce_matches?(grant.code_challenge, code_verifier)

      grant.update!(used_at: Time.current)
      mint(grant)
    end

    def self.pkce_matches?(code_challenge, code_verifier)
      expected = Base64.urlsafe_encode64(Digest::SHA256.digest(code_verifier), padding: false)
      ActiveSupport::SecurityUtils.secure_compare(expected, code_challenge)
    end
    private_class_method :pkce_matches?

    def self.mint(grant)
      raw_access = "hb_oat_#{SecureRandom.hex(24)}"
      raw_refresh = "hb_ort_#{SecureRandom.hex(24)}"

      token = AccessToken.create!(
        kind: "oauth", team_id: grant.team_id, membership_id: grant.membership_id, user_id: grant.user_id,
        oauth_client_id: grant.oauth_client_id, resource: grant.resource, scopes: grant.scopes, name: grant.oauth_client.name,
        token_digest: Digest::SHA256.hexdigest(raw_access), token_prefix: raw_access[0, 12],
        refresh_token_digest: Digest::SHA256.hexdigest(raw_refresh), refresh_family_id: SecureRandom.uuid,
        expires_at: OAuth::ACCESS_TOKEN_TTL.from_now
      )

      { access_token: raw_access, refresh_token: raw_refresh, scopes: token.scopes, expires_in: OAuth::ACCESS_TOKEN_TTL.to_i }
    end
    private_class_method :mint
  end
end
