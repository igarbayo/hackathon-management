# Resuelve cualquier Bearer de la API de dominio (no la ingesta de Claude
# Code, que tiene su propio TokenAuthentication) a un miembro/equipo/scopes,
# sea cual sea su prefijo (12-acceso-programatico.md#tipos-de-token).
# hb_oat_ (OAuth) y hb_it_ (integración) se añaden cuando existan esos flujos.
module Tokens
  Resolved = Struct.new(:kind, :team, :membership, :scopes, :token_record, :token_prefix, keyword_init: true) do
    def via(channel:, client: nil)
      { "channel" => channel, "token_kind" => kind, "token_id" => token_record&.id&.to_s, "token_prefix" => token_prefix, "client" => client }
    end
  end

  class Resolve
    MEMBER_PREFIX = "hb_mt_"
    PAT_PREFIX = "hb_pat_"

    # Scopes fijos del token de miembro (12-acceso-programatico.md#tipos-de-token):
    # CLI de hooks y MCP básico.
    MEMBER_SCOPES = %w[ingest read progress:write].freeze

    def self.call(raw_token)
      return nil if raw_token.blank?

      if raw_token.start_with?(MEMBER_PREFIX)
        resolve_member(raw_token)
      elsif raw_token.start_with?(PAT_PREFIX)
        resolve_pat(raw_token)
      end
    end

    def self.resolve_member(raw_token)
      membership = Membership.where("claude_code.token_digest" => Digest::SHA256.hexdigest(raw_token)).first
      return nil unless membership && !membership.claude_code.paused

      Resolved.new(kind: "member", team: membership.team, membership: membership, scopes: MEMBER_SCOPES, token_prefix: membership.claude_code.token_prefix)
    end
    private_class_method :resolve_member

    def self.resolve_pat(raw_token)
      token = AccessToken.active.where(kind: "pat", token_digest: Digest::SHA256.hexdigest(raw_token)).first
      return nil unless token

      touch_last_used(token)
      Resolved.new(kind: "pat", team: token.team, membership: token.membership, scopes: token.scopes, token_record: token, token_prefix: token.token_prefix)
    end
    private_class_method :resolve_pat

    # Resolución de 1 min (RF-API-003): no escribe en cada petición.
    def self.touch_last_used(token)
      return if token.last_used_at && token.last_used_at > 1.minute.ago

      token.set(last_used_at: Time.current)
    end
    private_class_method :touch_last_used
  end
end
