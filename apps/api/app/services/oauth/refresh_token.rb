# POST /oauth/token, grant_type=refresh_token (RNF-SEC-015): rotado en
# cada uso; si se reutiliza uno ya usado, se revoca toda la conexión
# (detección de robo). Cada rotación crea una fila nueva de AccessToken en
# vez de mutar la existente, para poder saber si la que llega está
# "superada" por una más nueva de la misma refresh_family_id.
module OAuth
  class RefreshToken
    class ReuseDetected < StandardError; end

    def self.call(refresh_token:, client_id:)
      digest = Digest::SHA256.hexdigest(refresh_token.to_s)
      token = AccessToken.where(kind: "oauth", refresh_token_digest: digest).first
      raise ReuseDetected, "refresh token inválido" unless token
      raise ReuseDetected, "client_id no coincide" unless token.oauth_client&.client_id == client_id

      if superseded?(token) || token.revoked?
        revoke_family!(token.refresh_family_id)
        raise ReuseDetected, "refresh token reutilizado: se ha revocado la conexión"
      end

      raise ReuseDetected, "refresh token caducado" if token.created_at + OAuth::REFRESH_TOKEN_TTL <= Time.current
      raise ReuseDetected, "la conexión ha caducado, hay que volver a autorizarla" if connection_expired?(token)

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
