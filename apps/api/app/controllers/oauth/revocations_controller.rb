# POST /oauth/revoke (RFC 7009). Sin sesión: poseer el token ya autoriza a
# revocarlo. Responde 200 siempre (RFC 7009: no distingue "no existía" de
# "revocado", para no dar pistas).
module OAuth
  class RevocationsController < ApplicationController
    def create
      digest = Digest::SHA256.hexdigest(params[:token].to_s)
      token = AccessToken.where(kind: "oauth").any_of({ token_digest: digest }, { refresh_token_digest: digest }).first
      token&.update!(revoked_at: Time.current, revoke_reason: "manual")

      head :ok
    end
  end
end
