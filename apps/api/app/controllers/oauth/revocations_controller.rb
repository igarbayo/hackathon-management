# POST /oauth/revoke (RFC 7009). No session: holding the token is enough to
# revoke it. It always returns 200 (RFC 7009: it does not tell "did not exist"
# from "revoked", to give no hints).
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
