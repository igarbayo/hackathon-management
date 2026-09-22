# Nunca expone token_digest ni el valor en claro (RNF-SEC-002): eso solo se
# devuelve una vez, en la respuesta de creación.
class AccessTokenSerializer
  def initialize(token)
    @token = token
  end

  def as_json
    {
      id: token.id.to_s,
      kind: token.kind,
      name: token.name,
      token_prefix: token.token_prefix,
      scopes: token.scopes,
      membership_id: token.membership_id&.to_s,
      created_by_id: token.created_by_id&.to_s,
      expires_at: token.expires_at&.iso8601,
      last_used_at: token.last_used_at&.iso8601,
      revoked_at: token.revoked_at&.iso8601
    }
  end

  private

  attr_reader :token
end
