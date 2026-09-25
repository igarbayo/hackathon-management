# POST /oauth/token, grant_type=refresh_token (RNF-SEC-015): rotated on every
# use; if an already used one is reused, the whole connection is revoked (theft
# detection). Each rotation creates a new AccessToken row instead of changing
# the existing one, so we can tell whether the incoming one has been
# "superseded" by a newer one from the same refresh_family_id.
module OAuth
  class RefreshToken
    class ReuseDetected < StandardError; end

    def self.call(refresh_token:, client_id:)
      digest = Digest::SHA256.hexdigest(refresh_token.to_s)
      token = AccessToken.where(kind: "oauth", refresh_token_digest: digest).first
      raise ReuseDetected, "invalid refresh token" unless token
      raise ReuseDetected, "client_id does not match" unless token.oauth_client&.client_id == client_id

      if superseded?(token) || token.revoked?
        revoke_family!(token.refresh_family_id)
        raise ReuseDetected, "refresh token reused: the connection has been revoked"
      end

      raise ReuseDetected, "refresh token expired" if token.created_at + OAuth::REFRESH_TOKEN_TTL <= Time.current
      raise ReuseDetected, "the connection has expired, authorize it again" if connection_expired?(token)

      mint_next(token)
    end

    def self.superseded?(token)
      AccessToken.where(refresh_family_id: token.refresh_family_id).where(:created_at.gt => token.created_at).exists?
    end
    private_class_method :superseded?

    def self.connection_expired?(token)
      first = AccessToken.where(refresh_family_id: token.refresh_family_id).order(created_at: :asc).first
      first.created_at + OAuth::MAX_CONNECTION_LIFETIME <= Time.current
    end
    private_class_method :connection_expired?

    def self.revoke_family!(family_id)
      return if family_id.blank?

      AccessToken.where(refresh_family_id: family_id, revoked_at: nil).each do |t|
        t.update!(revoked_at: Time.current, revoke_reason: "refresh_reuse")
      end
    end
    private_class_method :revoke_family!

    def self.mint_next(token)
      raw_access = "hb_oat_#{SecureRandom.hex(24)}"
      raw_refresh = "hb_ort_#{SecureRandom.hex(24)}"

      new_token = AccessToken.create!(
        kind: "oauth", team_id: token.team_id, membership_id: token.membership_id, user_id: token.user_id,
        oauth_client_id: token.oauth_client_id, resource: token.resource, scopes: token.scopes, name: token.name,
        token_digest: Digest::SHA256.hexdigest(raw_access), token_prefix: raw_access[0, 12],
        refresh_token_digest: Digest::SHA256.hexdigest(raw_refresh), refresh_family_id: token.refresh_family_id,
        expires_at: OAuth::ACCESS_TOKEN_TTL.from_now
      )

      { access_token: raw_access, refresh_token: raw_refresh, scopes: new_token.scopes, expires_in: OAuth::ACCESS_TOKEN_TTL.to_i }
    end
    private_class_method :mint_next
  end
end
