# Bearer hb_mt_ -> current_membership/current_team (01-arquitectura.md). Spec 12
# adds the other prefixes (hb_pat_, hb_oat_, hb_it_).
#
# `paused` is NOT checked here: it is a property of the link, not a revocation,
# and the token must keep working to authenticate `PATCH /cli/me` (otherwise
# `hackboard resume` could never resume its own paused link). Each endpoint
# decides what to do with `paused` (Ingest::ProcessBatch drops incoming events;
# Cli::ConfigController and Cli::MeController keep working).
module TokenAuthentication
  extend ActiveSupport::Concern

  MEMBER_PREFIX = "hb_mt_"

  def authenticate_member_token!
    token = bearer_token
    raise ApiError::Unauthenticated.new(message: "missing token") if token.blank?
    raise ApiError::Unauthenticated.new(message: "unrecognized token") unless token.start_with?(MEMBER_PREFIX)

    membership = Membership.where("claude_code.token_digest" => Digest::SHA256.hexdigest(token)).first
    raise ApiError::Unauthenticated.new(message: "invalid or revoked token") unless membership && !membership.team.deleted?

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
