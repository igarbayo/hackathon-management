# Bearer hb_mt_ -> current_membership/current_team (01-arquitectura.md).
# Los demás prefijos (hb_pat_, hb_oat_, hb_it_) los añade la spec 12.
#
# `paused` NO se comprueba aquí: es un dato del enlace, no una revocación, y
# el token tiene que seguir sirviendo para autenticar `PATCH /cli/me` (si no,
# `hackboard resume` no podría reanudar nunca su propio enlace pausado). Cada
# endpoint decide qué hacer con `paused` (Ingest::ProcessBatch descarta los
# eventos entrantes; Cli::ConfigController y Cli::MeController siguen
# funcionando).
module TokenAuthentication
  extend ActiveSupport::Concern

  MEMBER_PREFIX = "hb_mt_"

  def authenticate_member_token!
    token = bearer_token
    raise ApiError::Unauthenticated.new(message: "falta el token") if token.blank?
    raise ApiError::Unauthenticated.new(message: "token no reconocido") unless token.start_with?(MEMBER_PREFIX)

    membership = Membership.where("claude_code.token_digest" => Digest::SHA256.hexdigest(token)).first
    raise ApiError::Unauthenticated.new(message: "token inválido o revocado") unless membership

    @current_membership = membership
    @current_team = membership.team
  end

  private

  def bearer_token
    header = request.headers["Authorization"]
    return nil unless header&.start_with?("Bearer ")

    header.delete_prefix("Bearer ")
  end

  def current_membership
    @current_membership
  end

  def current_team
    @current_team
  end
end
